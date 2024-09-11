// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {DISTR_CONTRACT} from "src/interfaces/IDistribution.sol";
import {STAKING_CONTRACT} from "src/interfaces/IStaking.sol";

import {EqSei} from "src/EqSei.sol";

contract EquoStaking is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error EquoStaking__LessThanMinimumAmount();
    error EquoStaking__InsufficientAmountToUnstake();
    error EquoStaking__RequestIndexOutOfBound();
    error EquoStaking__UnboundingPeriodNotFinished(uint256 timeRemaining);
    error EquoStaking__SeiTransferWhileWithdrawFailed();

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

    struct UndelegationRequest {
        uint256 exchangeRate;
        uint256 eqSeiAmount;
        uint256 requestTimestamp;
    }

    EqSei private eqSei;

    uint256 private constant UNBOUNDING_PERIOD = 21 days;
    uint256 private constant UNBOUNDING_BUFFER = 2 hours;

    uint256 private constant STARTING_EXCHANGE_RATE = 1e18;
    uint256 private constant MINIMUM_AMOUNT_TO_STAKE = 0.5 ether;
    bytes32 private constant DELEGATOR = keccak256("DELEGATOR");

    mapping(address => UndelegationRequest[]) private undelegationRequests;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address multiSigAddress, address tokenAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, multiSigAddress);
        eqSei = EqSei(tokenAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function stake() external payable {
        if (msg.value < MINIMUM_AMOUNT_TO_STAKE) {
            revert EquoStaking__LessThanMinimumAmount();
        }

        uint256 tokenMintAmount = msg.value * _getExchangeRate();

        eqSei.mint(msg.sender, tokenMintAmount);
    }

    function unstake(uint256 amount) external {
        if (eqSei.balanceOf(msg.sender) <= amount) {
            revert EquoStaking__InsufficientAmountToUnstake();
        }

        undelegationRequests[msg.sender].push(
            UndelegationRequest({
                exchangeRate: _getExchangeRate(),
                eqSeiAmount: amount,
                requestTimestamp: block.timestamp
            })
        );

        eqSei.burn(msg.sender, amount);
    }

    function withdraw(uint256 requestIndex) external {
        uint256 requestsLength = undelegationRequests[msg.sender].length;
        if (requestsLength < requestIndex) {
            revert EquoStaking__RequestIndexOutOfBound();
        }

        UndelegationRequest memory request = undelegationRequests[msg.sender][requestIndex];

        if (checkIfUnboundingFinished(request.requestTimestamp)) {
            revert EquoStaking__UnboundingPeriodNotFinished(
                (request.requestTimestamp + UNBOUNDING_PERIOD + UNBOUNDING_BUFFER) - block.timestamp
            );
        }

        (bool success, /*bytes memory dataReturned*/ ) =
            payable(msg.sender).call{value: (request.eqSeiAmount / request.exchangeRate)}("");

        if (!success) {
            revert EquoStaking__SeiTransferWhileWithdrawFailed();
        }

        undelegationRequests[msg.sender][requestIndex] = undelegationRequests[msg.sender][requestsLength - 1];
        undelegationRequests[msg.sender].pop();
    }

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

    function _getExchangeRate() internal view returns (uint256) {
        uint256 totalSupply = eqSei.totalSupply();

        if(totalSupply == 0) {
            return STARTING_EXCHANGE_RATE;
        } else {
            // logic in progress
            return 1e18;
        }
    }

    function getTotalDelegatedAmount() internal view returns(uint256) {
        
    }

    function checkIfUnboundingFinished(uint256 requestTimestamp) internal view returns (bool) {
        if (block.timestamp > requestTimestamp + UNBOUNDING_PERIOD + UNBOUNDING_BUFFER) {
            return false;
        } else {
            return true;
        }
    }

    /*//////////////////////////////////////////////////////////////
                     PUBLIC/EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getExchangeRate() public view returns (uint256) {}
}
