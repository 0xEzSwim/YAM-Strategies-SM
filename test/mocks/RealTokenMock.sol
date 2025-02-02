// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBridgeToken} from "../../src/markets/interfaces/IBridgeToken.sol";

contract RealTokenMock is ERC20, IBridgeToken {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function allowance(address _owner, address _spender) public view override(ERC20, IBridgeToken) returns (uint256) {
        return ERC20.allowance(_owner, _spender);
    }

    function transferFrom(address from, address to, uint256 value)
        public
        override(ERC20, IBridgeToken)
        returns (bool)
    {
        return ERC20.transferFrom(from, to, value);
    }

    function rules() external view override returns (uint256[] memory, uint256[] memory) {}

    function rule(uint256 ruleId) external view override returns (uint256, uint256) {}

    function owner() external view override returns (address) {}

    function canTransfer(address _from, address _to, uint256 _amount)
        external
        pure
        override
        returns (bool, uint256, uint256)
    {
        return (true, 0, 0);
    }

    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external override {}
}
