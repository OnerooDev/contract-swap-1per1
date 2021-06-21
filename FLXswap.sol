pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title FLXswap Contract
 */
contract FLXswap is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using SafeMath  for uint112;

    IERC20 private token0;
    IERC20 private token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    event Sync(uint112 reserve0, uint112 reserve1);

    /**
     * @dev Constructor sets token that can be received
     */
    constructor (IERC20 _token0, IERC20 _token1) public {
      token0 = _token0;
      token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function swapToBSC(uint256 amount) external nonReentrant {
        require(amount > 0, 'FLXswap: INSUFFICIENT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount <= _reserve0, 'FLXswap: INSUFFICIENT_BSC_xFL');
        require(IERC20(token1).balanceOf(msg.sender) >= amount, "FLXswap: USER_NOT_ENOUGHT_ETH_xFL");

        uint b_balance0 = _reserve0.sub(amount);
        uint b_balance1 = _reserve1.add(amount);

        _stake(token1, amount);
        _send(token0, amount);
        _update(b_balance0, b_balance1);
    }

    function swapToETH(uint256 amount) external nonReentrant {
        require(amount > 0, 'FLXswap: INSUFFICIENT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount <= _reserve1, 'FLXswap: INSUFFICIENT_ETH_xFL');
        require(IERC20(token0).balanceOf(msg.sender) >= amount, "FLXswap: NOT_ENOUGHT_BSC_xFL");

        uint e_balance0 = _reserve0.add(amount);
        uint e_balance1 = _reserve1.sub(amount);

        _stake(token0, amount);
        _send(token1, amount);
        _update(e_balance0, e_balance1);
    }

    // force reserves to match balances
    function sync() external {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    /**
     * @dev Iniciate Stake, xFL(BSC) tokens
     */
    function doStake(uint256 amount) external onlyOwner {
        require(amount > 0, 'FLXswap: INSUFFICIENT_AMOUNT');

        _stake(token0, amount);

        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    /**
     * @dev Iniciate EndStake, xFL(BSC) tokens
     */
    function endStake(uint256 amount) external onlyOwner {
        require(amount > 0, 'FLXswap: INSUFFICIENT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount <= _reserve0, 'FLXswap: INSUFFICIENT_ETH_xFL');

        _send(token0, amount);
        uint end_balance0 = _reserve0.sub(amount);

        _update(end_balance0, _reserve1);
    }

    /**
      * @dev Privates functions
      */

      // update reserves
    function _update(uint balance0, uint balance1) internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _send(IERC20 token, uint256 amount) internal {
        address to = msg.sender;

        token.safeTransfer(to, amount);
    }

    function _stake(IERC20 token, uint256 amount) internal {
        address from = msg.sender;
        uint256 allow_amount = IERC20(token).allowance(msg.sender, address(this));
        require(amount <= allow_amount, 'FLXswap: NOT_APPROVED_AMOUNT');

        token.transferFrom(from, address(this), amount);
    }

}
