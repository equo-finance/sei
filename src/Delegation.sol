// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {STAKING_CONTRACT} from "src/interfaces/IStaking.sol";
import {DISTR_CONTRACT} from "src/interfaces/IDistribution.sol";

import {EquoStaking} from "src/EquoStaking.sol";

contract Delegation is EquoStaking, AccessControl {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant DELEGATOR = keccak256("DELEGATOR");

    /*//////////////////////////////////////////////////////////////
                          DELEGATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function delegate(address[] calldata validatorAddresses, uint256[] calldata amountPerValidator)
        external
        onlyRole(DELEGATOR)
    {}

    function redelegate(
        address[] calldata oldValidatorAddresses,
        address[] calldata newValidatorAddresses,
        uint256[] calldata amountPerValidator
    ) external onlyRole(DELEGATOR) {}

    function undelegate(address[] calldata validatorAddresses, uint256[] calldata amountPerValidator)
        external
        onlyRole(DELEGATOR)
    {}
    function claimReward(address[] calldata validatorAddresses) external onlyRole(DELEGATOR) {}

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice adds new address as delegator
     *
     * @dev adds address of new delegation bot
     * @dev assume DEFAULT_ADMIN_ROLE will be calling this function and access control
     * @dev will be handled by `grantRole` function internally.
     * @dev function allows to have multiple delegation bots for redundency
     *
     * @param newDelegator address of new delegation bot
     */
    function setDelegator(address newDelegator) external {
        grantRole(DELEGATOR, newDelegator);
    }

    /**
     * @notice removes delegator from the list of the delegator
     * @param delegator address of delegator to be removed
     */
    function removeDelegator(address delegator) external {
        grantRole(DELEGATOR, delegator);
    }
}
