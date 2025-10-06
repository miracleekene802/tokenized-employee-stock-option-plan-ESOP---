import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure token metadata is correct",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-name', [], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-symbol', [], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-decimals', [], deployer.address),
        ]);
        
        assertEquals(block.receipts[0].result, '(ok "ESOP Token")');
        assertEquals(block.receipts[1].result, '(ok "ESOP")');
        assertEquals(block.receipts[2].result, '(ok u6)');
    },
});

Clarinet.test({
    name: "Test option granting functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const employee = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'grant-options', [
                types.principal(employee.address),
                types.uint(1000),
                types.uint(100), // cliff blocks
                types.uint(400)  // vesting blocks
            ], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Check grant was created
        let grantBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-employee-grant', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        const grant = grantBlock.receipts[0].result.expectSome();
        grant.expectTuple()['total-allocation'].expectUint(1000);
        grant.expectTuple()['cliff-blocks'].expectUint(100);
        grant.expectTuple()['vesting-blocks'].expectUint(400);
    },
});

Clarinet.test({
    name: "Test vesting calculation before cliff",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const employee = accounts.get('wallet_1')!;
        
        // Grant options
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'grant-options', [
                types.principal(employee.address),
                types.uint(1000),
                types.uint(100), // cliff blocks
                types.uint(400)  // vesting blocks
            ], deployer.address),
        ]);
        
        // Check vested amount before cliff (should be 0)
        let vestBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'calculate-vested-amount', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        vestBlock.receipts[0].result.expectUint(0);
    },
});

Clarinet.test({
    name: "Test vesting calculation after cliff",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const employee = accounts.get('wallet_1')!;
        
        // Grant options
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'grant-options', [
                types.principal(employee.address),
                types.uint(1000),
                types.uint(50), // cliff blocks
                types.uint(200)  // vesting blocks
            ], deployer.address),
        ]);
        
        // Mine blocks to pass cliff
        chain.mineEmptyBlockUntil(60);
        
        // Check vested amount after cliff
        let vestBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'calculate-vested-amount', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        // Should have some vested amount now
        const vestedAmount = vestBlock.receipts[0].result.expectUint();
        assertEquals(vestedAmount > 0, true);
    },
});

Clarinet.test({
    name: "Test option exercising",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const employee = accounts.get('wallet_1')!;
        
        // Grant options
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'grant-options', [
                types.principal(employee.address),
                types.uint(1000),
                types.uint(10), // cliff blocks
                types.uint(100)  // vesting blocks
            ], deployer.address),
        ]);
        
        // Mine blocks to pass cliff and vest some options
        chain.mineEmptyBlockUntil(50);
        
        // Vest options
        let vestBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'vest-options', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        vestBlock.receipts[0].result.expectOk();
        
        // Exercise options
        let exerciseBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'exercise-options', [
                types.uint(100)
            ], employee.address),
        ]);
        
        exerciseBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Check token balance
        let balanceBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-balance', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        balanceBlock.receipts[0].result.expectUint(100);
    },
});

Clarinet.test({
    name: "Test board member functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const boardMember = accounts.get('wallet_1')!;
        
        // Add board member
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'add-board-member', [
                types.principal(boardMember.address)
            ], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Check is board member
        let checkBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'is-board-member', [
                types.principal(boardMember.address)
            ], deployer.address),
        ]);
        
        checkBlock.receipts[0].result.expectBool(true);
    },
});

Clarinet.test({
    name: "Test corporate tokenomics functions",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Update company valuation
        let block = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'update-company-valuation', [
                types.uint(10000000) // $10M valuation
            ], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'update-total-shares', [
                types.uint(1000000) // 1M shares
            ], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'update-exercise-price', [
                types.uint(5) // $5 exercise price
            ], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        block.receipts[1].result.expectOk().expectBool(true);
        block.receipts[2].result.expectOk().expectBool(true);
        
        // Check values
        let checkBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-company-valuation', [], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-total-shares', [], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-exercise-price', [], deployer.address),
        ]);
        
        checkBlock.receipts[0].result.expectUint(10000000);
        checkBlock.receipts[1].result.expectUint(1000000);
        checkBlock.receipts[2].result.expectUint(5);
    },
});

Clarinet.test({
    name: "Test option value calculation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const employee = accounts.get('wallet_1')!;
        
        // Set up company metrics
        let setupBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'update-company-valuation', [
                types.uint(10000000) // $10M valuation
            ], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'update-total-shares', [
                types.uint(1000000) // 1M shares = $10 per share
            ], deployer.address),
            Tx.contractCall('tokenized-employee-stock-option-plan', 'update-exercise-price', [
                types.uint(5) // $5 exercise price, so $5 intrinsic value per share
            ], deployer.address),
        ]);
        
        // Grant options
        let grantBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'grant-options', [
                types.principal(employee.address),
                types.uint(1000),
                types.uint(10), // cliff blocks
                types.uint(100)  // vesting blocks
            ], deployer.address),
        ]);
        
        // Mine blocks to vest options
        chain.mineEmptyBlockUntil(100);
        
        // Calculate option value (should be 1000 * $5 = $5000)
        let valueBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'calculate-option-value', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        valueBlock.receipts[0].result.expectUint(5000);
    },
});

Clarinet.test({
    name: "Test grant revocation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const employee = accounts.get('wallet_1')!;
        
        // Grant options
        let grantBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'grant-options', [
                types.principal(employee.address),
                types.uint(1000),
                types.uint(100),
                types.uint(400)
            ], deployer.address),
        ]);
        
        // Revoke grant
        let revokeBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'revoke-grant', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        revokeBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Check grant is inactive
        let checkBlock = chain.mineBlock([
            Tx.contractCall('tokenized-employee-stock-option-plan', 'get-employee-grant', [
                types.principal(employee.address)
            ], deployer.address),
        ]);
        
        const grant = checkBlock.receipts[0].result.expectSome();
        grant.expectTuple()['active'].expectBool(false);
    },
});
