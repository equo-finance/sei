// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {DISTR_CONTRACT} from "src/interfaces/IDistribution.sol";
import {STAKING_CONTRACT} from "src/interfaces/IStaking.sol";


contract EquoStaking is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error EquoStaking__LessThanMinimumAmount();

    error EquoStaking__MismatchInArrayLength();
    error EquoStaking__DelegationFailed();
    error EquoStaking__RedelegationFailed();
    error EquoStaking__UndelegationFailed();
    error EquoStaking__RewardClaimFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event EquoStaking__TokenStaked(uint256 indexed amount, address indexed account);
    event EquoStaking__TokenUnstaked(uint256 indexed amount, address indexed account);
    event EquoStaking__SeiWithdrawn(uint256 indexed amount, address indexed account);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MINIMUM_AMOUNT_TO_STAKE = 0.5 ether;

    bytes32 public constant DELEGATOR = keccak256("DELEGATOR");
    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address multiSigAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, multiSigAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function stake() external payable {}
    function unstake() external {}
    function withdraw() external {}

    /*//////////////////////////////////////////////////////////////
                          DELEGATOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Delegates funds to the specified validators.
     * @dev Validator addresses are represented as `string` instead of the `address` type.
     * @param validatorAddressList An array of validator addresses to delegate funds to.
     * @param amountToDelegatePerValidator An array of amounts to be delegated to each validator, in the same order as `validatorAddresses`.
     */
    function delegate(string[] calldata validatorAddressList, uint256[] calldata amountToDelegatePerValidator)
        external
        onlyRole(DELEGATOR)
    {
        if (validatorAddressList.length != amountToDelegatePerValidator.length) {
            revert EquoStaking__MismatchInArrayLength();
        }

        uint256 arrayLength = validatorAddressList.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            bool success = STAKING_CONTRACT.delegate{value: amountToDelegatePerValidator[i]}(validatorAddressList[i]);
            if (!success) {
                revert EquoStaking__DelegationFailed();
            }
        }
    }

    /**
     * @notice Redelegates funds from one set of validators to another.
     * @dev The amounts in the `amountToRedelegate` array should be in 6 decimal places because the native token
     * @dev on the Cosmos side uses 6 decimals, unlike the 18 decimals used on the EVM side.
     *
     * @param previousValidatorAddressList An array of validators from whom funds will be redelegated.
     * @param newValidatorAddressList An array of validators to whom funds will be redelegated.
     * @param amountToRedelegatePerValidator An array of amounts to redelegate, in 6 decimals.
     */
    function redelegate(
        string[] calldata previousValidatorAddressList,
        string[] calldata newValidatorAddressList,
        uint256[] calldata amountToRedelegatePerValidator
    ) external onlyRole(DELEGATOR) {
        if (
            previousValidatorAddressList.length != newValidatorAddressList.length
                || newValidatorAddressList.length != amountToRedelegatePerValidator.length
        ) {
            revert EquoStaking__MismatchInArrayLength();
        }

        uint256 arrayLength = previousValidatorAddressList.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            bool success = STAKING_CONTRACT.redelegate(
                previousValidatorAddressList[i], newValidatorAddressList[i], amountToRedelegatePerValidator[i]
            );
            if (!success) {
                revert EquoStaking__RedelegationFailed();
            }
        }
    }

    /**
     * @notice Undelegates funds from the specified validators.
     * @dev Validator addresses are represented as `string`. Amounts should be in 6 decimals.
     * @param validatorAddressList An array of validator addresses from which funds will be undelegated.
     * @param amountToUndelegatePerValidator An array of amounts to undelegate from each validator, in 6 decimals.
     */
    function undelegate(string[] calldata validatorAddressList, uint256[] calldata amountToUndelegatePerValidator)
        external
        onlyRole(DELEGATOR)
    {
        if (validatorAddressList.length != amountToUndelegatePerValidator.length) {
            revert EquoStaking__MismatchInArrayLength();
        }

        uint256 arrayLength = validatorAddressList.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            bool success = STAKING_CONTRACT.undelegate(validatorAddressList[i], amountToUndelegatePerValidator[i]);
            if (!success) {
                revert EquoStaking__UndelegationFailed();
            }
        }
    }

    /**
     * @notice Claims rewards from the specified validators.
     * @param validatorAddressList An array of validator addresses from which rewards will be claimed.
     */
    function claimReward(string[] calldata validatorAddressList) external onlyRole(DELEGATOR) {
        bool success = DISTR_CONTRACT.withdrawMultipleDelegationRewards(validatorAddressList);
        if (!success) {
            revert EquoStaking__RewardClaimFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Assigns a new delegator to manage staking operations.
     *
     * @dev Adds the address of a new delegation bot with the `DELEGATOR` role.
     * @dev It is assumed that this function is called by an account with the `DEFAULT_ADMIN_ROLE`, and access control is managed internally via the `grantRole` function.
     * @dev Allows multiple delegation bots to be added for redundancy purposes.
     *
     * @param newDelegator The address of the new delegation bot to be assigned the `DELEGATOR` role.
     */
    function setDelegator(address newDelegator) external {
        grantRole(DELEGATOR, newDelegator);
    }

    /**
     * @notice Revokes the `DELEGATOR` role from a specified delegator.
     * @param delegator delegator The address of the delegator to be removed.
     */
    function removeDelegator(address delegator) external {
        grantRole(DELEGATOR, delegator);
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL/PRIVATE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getExchangeRate() internal view returns (uint256) {}

    /*//////////////////////////////////////////////////////////////
                     PUBLIC/EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getExchangeRate() public view returns (uint256) {}
}
