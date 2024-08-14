// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../tokens/OmniLSTPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OmniLSTPoolTest is Test {
    OmniLSTPool pool;
    MockERC20 token1;
    MockERC20 token2;
    MockERC20 token3;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);

    function setUp() public {
        vm.startPrank(owner);
        pool = new OmniLSTPool("OmniLST Pool", "OLST");
        token1 = new MockERC20("Token1", "TKN1");
        token2 = new MockERC20("Token2", "TKN2");
        token3 = new MockERC20("Token3", "TKN3");

        pool.whitelistToken(address(token1));
        pool.whitelistToken(address(token2));
        pool.whitelistToken(address(token3));

        pool.setTargetAllocation(address(token1), 4e17); // 40%
        pool.setTargetAllocation(address(token2), 4e17); // 40%
        pool.setTargetAllocation(address(token3), 2e17); // 20%

        vm.stopPrank();

        // Mint tokens to users
        token1.mint(user1, 1000e18);
        token2.mint(user1, 1000e18);
        token3.mint(user1, 1000e18);
        token1.mint(user2, 1000e18);
        token2.mint(user2, 1000e18);
        token3.mint(user2, 1000e18);
    }

    // Basic deposit test
    function testDeposit() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        uint256 shares = pool.deposit(address(token1), 100e18);
        assertEq(shares, 100e18);
        assertEq(pool.balanceOf(user1), 100e18);
        assertEq(token1.balanceOf(address(pool)), 100e18);
        vm.stopPrank();
    }

    // Basic withdraw test
    function testWithdraw() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        pool.deposit(address(token1), 100e18);
        uint256 withdrawnAmount = pool.withdraw(address(token1), 50e18);
        assertEq(withdrawnAmount, 50e18);
        assertEq(pool.balanceOf(user1), 50e18);
        assertEq(token1.balanceOf(address(pool)), 50e18);
        vm.stopPrank();
    }

    // Test deposit with multiple users
    function testMultiUserDeposit() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        pool.deposit(address(token1), 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        token2.approve(address(pool), 100e18);
        pool.deposit(address(token2), 100e18);
        vm.stopPrank();

        assertEq(pool.balanceOf(user1), 100e18);
        assertEq(pool.balanceOf(user2), 100e18);
        assertEq(pool.totalSupply(), 200e18);
    }

    // Test swap
    function testSwap() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        pool.deposit(address(token1), 100e18);
        token2.approve(address(pool), 50e18);
        uint256 amountOut = pool.swap(address(token2), address(token1), 50e18);
        assertGt(amountOut, 0);
        assertLt(amountOut, 50e18); // Expect some swap fee
        vm.stopPrank();
    }

    // Edge case: Deposit 0 amount
    function testFailDepositZero() public {
        vm.prank(user1);
        pool.deposit(address(token1), 0);
    }

    // Edge case: Withdraw more than balance
    function testFailWithdrawTooMuch() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        pool.deposit(address(token1), 100e18);
        pool.withdraw(address(token1), 101e18);
        vm.stopPrank();
    }

    // Edge case: Swap non-whitelisted token
    function testFailSwapNonWhitelisted() public {
        MockERC20 nonWhitelistedToken = new MockERC20("NonWhitelisted", "NWT");
        vm.startPrank(user1);
        nonWhitelistedToken.approve(address(pool), 100e18);
        pool.swap(address(nonWhitelistedToken), address(token1), 100e18);
        vm.stopPrank();
    }

    // Fuzz test: Deposit random amounts
    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000e18);
        vm.startPrank(user1);
        token1.approve(address(pool), amount);
        uint256 shares = pool.deposit(address(token1), amount);
        assertEq(shares, amount);
        assertEq(pool.balanceOf(user1), amount);
        assertEq(token1.balanceOf(address(pool)), amount);
        vm.stopPrank();
    }

    // Fuzz test: Deposit and withdraw random amounts
    function testFuzzDepositAndWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= 1000e18);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);

        vm.startPrank(user1);
        token1.approve(address(pool), depositAmount);
        pool.deposit(address(token1), depositAmount);

        uint256 withdrawnAmount = pool.withdraw(address(token1), withdrawAmount);
        assertEq(withdrawnAmount, withdrawAmount);
        assertEq(pool.balanceOf(user1), depositAmount - withdrawAmount);
        assertEq(token1.balanceOf(address(pool)), depositAmount - withdrawAmount);
        vm.stopPrank();
    }

    // Fuzz test: Swap random amounts
    function testFuzzSwap(uint256 depositAmount, uint256 swapAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= 1000e18);
        vm.assume(swapAmount > 0 && swapAmount <= depositAmount);

        vm.startPrank(user1);
        token1.approve(address(pool), depositAmount);
        pool.deposit(address(token1), depositAmount);

        token2.approve(address(pool), swapAmount);
        uint256 amountOut = pool.swap(address(token2), address(token1), swapAmount);
        assertGt(amountOut, 0);
        assertLt(amountOut, swapAmount); // Expect some swap fee
        vm.stopPrank();
    }

    // Test pool share calculation
    function testPoolShare() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        pool.deposit(address(token1), 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        token2.approve(address(pool), 100e18);
        pool.deposit(address(token2), 100e18);
        vm.stopPrank();

        assertEq(pool.getPoolShare(address(token1)), 5e17); // 50%
        assertEq(pool.getPoolShare(address(token2)), 5e17); // 50%
    }

    // Test total pool value calculation
    function testTotalPoolValue() public {
        vm.startPrank(user1);
        token1.approve(address(pool), 100e18);
        pool.deposit(address(token1), 100e18);
        token2.approve(address(pool), 50e18);
        pool.deposit(address(token2), 50e18);
        vm.stopPrank();

        assertEq(pool.getTotalPoolValue(), 150e18);
    }

    // Test setting parameters (this is a placeholder as the actual implementation may vary)
    function testSetParameters() public {
        vm.prank(owner);
        pool.setParameters("testParam", "testValue");
        // Add assertions based on the actual implementation
    }

    // Invariant: Total supply should always equal total pool value
    function invariant_totalSupplyEqualsTotalPoolValue() public {
        assertEq(pool.totalSupply(), pool.getTotalPoolValue());
    }

    // Invariant: Sum of all token balances should equal total supply
    function invariant_sumOfBalancesEqualsTotalSupply() public {
        uint256 sumOfBalances = token1.balanceOf(address(pool)) +
                                token2.balanceOf(address(pool)) +
                                token3.balanceOf(address(pool));
        assertEq(sumOfBalances, pool.totalSupply());
    }
}