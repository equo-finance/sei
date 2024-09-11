// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EqSei is ERC20, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event EqSei__TokenMinted(uint256 value);
    event EqSei__TokenBurned(uint256 value);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice This function mints the token to address depositing tokens in liquid staking contract.
     * @dev The amount of token to mint will depend on the exchange rate of $EQSEI<>$SEI which will be calculated in liquid staking contract.
     * @param account address of user depositing $SEI in the protocol
     * @param value amount of $EQSEI to mint
     */
    function mint(address account, uint256 value) external onlyOwner {
        _mint(account, value);

        emit EqSei__TokenMinted(value);
    }

    /**
     * @notice This function burns the $EQSEI and reduces the total supply of $EQSEI.
     * @param account address of user burning $EQSEI
     * @param value amount of $EQSEI to burn
     */
    function burn(address account, uint256 value) external onlyOwner {
        _burn(account, value);

        emit EqSei__TokenBurned(value);
    }
}
