// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Interfaces.sol";
import "@openzeppelin/contracts-0.6/math/SafeMath.sol";
import "@openzeppelin/contracts-0.6/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-0.6/token/ERC20/SafeERC20.sol";

interface IRewardDeposit {
    function addReward(address _token, uint256 _amount) external;
}

/**
 * @title   ExtraRewardStashTokenRescue
 * @author  ConvexFinance
 * @notice  Rescue ERC20 tokens from the VoterProxy
 *          This is basically a special ExtraRewardStashV3 which was temporarily added as the
 *          V3 implementation for the StashFactory then a special pool was added to the Booster 
 *          with a RescueToken rewards get sent to ether the vlCvxExtraRewardDistribution or
 *          the treasury
 *          - Can only collect non-LP and non-gauge tokens
 *          - Should not be set to collect tokens used as incentives in v2 gauges
 */
contract ExtraRewardStashTokenRescue {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public pid;
    address public operator;
    address public staker;
    address public gauge;
    address public rewardFactory;

    address public distributor;
    address public rewardDeposit;
    address public treasuryDeposit;
   
    //active tokens that can be claimed. tokenaddress -> claimOption
    mapping(address => uint256) public activeTokens;

    enum Options{
        SendToRewards,
        SendToTreasury
    }

    constructor() public {
    }

    function initialize(uint256 _pid, address _operator, address _staker, address _gauge, address _rFactory) external {
        require(gauge == address(0),"!init");
        pid = _pid;
        operator = _operator;
        staker = _staker;
        gauge = _gauge;
        rewardFactory = _rFactory;
    }

    function getName() external pure returns (string memory) {
        return "ExtraRewardStashTokenRescue";
    }

    function CheckOption(uint256 _mask, uint256 _flag) internal pure returns(bool){
        return (_mask & (1<<_flag)) != 0;
    }

    //try claiming if there are reward tokens registered
    function claimRewards() external pure returns (bool) {
        return true;
    }

    /**
     * @notice  Claim reward tokens and either send them to the rewardDeposit (vlCvxExtraRewardDistribution)
     *          or send then directly to the treasury
     * @param _token ERC20 token to claim from staked (VoterProxy)
     */
    function claimRewardToken(address _token) public returns (bool) {
        require(distributor == address(0) || msg.sender == distributor, "!distributor");
        require(activeTokens[_token] > 0,"!active");
        
        uint256 onstaker = IERC20(_token).balanceOf(staker);
        if(onstaker > 0){
            IStaker(staker).withdraw(_token);
        }

        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount > 0) {
            if(rewardDeposit != address(0) && CheckOption(activeTokens[_token],uint256(Options.SendToRewards))){
                IRewardDeposit(rewardDeposit).addReward(_token,amount);
                emit TokenClaimed(_token, rewardDeposit, amount);
            }else{
                //if reward deposit not set or option set to treasury, send directly to treasury address
                IERC20(_token).safeTransfer(treasuryDeposit,amount);
                emit TokenClaimed(_token, treasuryDeposit, amount);
            }
        }
        return true;
    }
   

    function setDistribution(address _distributor, address _rewardDeposit, address _treasury) external{
        require(IDeposit(operator).owner() == msg.sender, "!owner");
        distributor = _distributor;
        rewardDeposit = _rewardDeposit;
        treasuryDeposit = _treasury;
    }

    /**
     * @notice Register an extra reward token to be handled
     */
    function setExtraReward(address _token, uint256 _option) external{
        //owner of booster can set extra rewards
        require(IDeposit(operator).owner() == msg.sender, "!owner");
        
        activeTokens[_token] = _option;
        if(CheckOption(_option,uint256(Options.SendToRewards)) && rewardDeposit != address(0)){
            IERC20(_token).safeApprove(rewardDeposit,0);
            IERC20(_token).safeApprove(rewardDeposit,uint256(-1));
        }
        emit TokenSet(_token, _option);
    }

    //pull assigned tokens from staker to stash
    function stashRewards() external pure returns(bool){
        return true;
    }

    //send all extra rewards to their reward contracts
    function processStash() external pure returns(bool){
        return true;
    }

    /* ========== EVENTS ========== */
    event TokenSet(address indexed _token, uint256 _option);
    event TokenClaimed(address indexed _token, address indexed _receiver, uint256 _amount);
}
