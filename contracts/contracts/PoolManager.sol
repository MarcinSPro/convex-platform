// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Interfaces.sol";
import "@openzeppelin/contracts-0.6/math/SafeMath.sol";
import "@openzeppelin/contracts-0.6/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-0.6/utils/Address.sol";
import "@openzeppelin/contracts-0.6/token/ERC20/SafeERC20.sol";



/**
 * @title   PoolManager
 * @author  ConvexFinance
 * @notice  Add pool to Booster. Deprecate, use PoolManagerV3 now.
 */
contract PoolManager{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public operator;
    address public immutable pools;
    address public immutable registry;

    /**
     * @param _pools      Contract to call addPool on (Booster)
     * @param _registry   Curve registry
     */
    constructor(address _pools, address _registry) public {
        operator = msg.sender;
        pools = _pools;
        registry = _registry;
    }

    function setOperator(address _operator) external {
        require(msg.sender == operator, "!auth");
        operator = _operator;
    }

    //revert control of adding  pools back to operator
    function revertControl() external{
        require(msg.sender == operator, "!auth");
        IPools(pools).setPoolManager(operator);
    }

    /**
     * @notice  Add a new curve pool to the system.
     * @dev     This function is callable by anyone. The gauge must be on curve's registry. 
     * @param _swap           LP Token
     * @param _gauge          Gauge contract
     * @param _stashVersion   ExtraRewardStash version
     */
    function addPool(address _swap, address _gauge, uint256 _stashVersion) external returns(bool){
        require(_gauge != address(0),"gauge is 0");
        require(_swap != address(0),"swap is 0");

        //get curve's registery
        address mainReg = IRegistry(registry).get_registry();
        
        //get lp token and gauge list from swap address
        address lptoken = IRegistry(mainReg).get_lp_token(_swap);

        (address[10] memory gaugeList,) = IRegistry(mainReg).get_gauges(_swap);

        //confirm the gauge passed in calldata is in the list
        //  a passed gauge address is needed if there is ever multiple gauges
        //  as the fact that an array is returned implies.
        bool found = false;
        for(uint256 i = 0; i < gaugeList.length; i++){
            if(gaugeList[i] == _gauge){
                found = true;
                break;
            }
        }
        require(found, "!registry");

        bool gaugeExists = IPools(pools).gaugeMap(_gauge);
        require(!gaugeExists, "already registered");
        
        IPools(pools).addPool(lptoken,_gauge,_stashVersion);

        return true;
    }

    function shutdownPool(uint256 _pid) external returns(bool){
        require(msg.sender==operator, "!auth");

        IPools(pools).shutdownPool(_pid);
        return true;
    }

}
