// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Receptor {

    string public lastCalledFunction;

    receive() external payable {
        lastCalledFunction = "receive";
    }

    fallback() external payable {
        lastCalledFunction = "fallback";
    }

    function deposit() external payable {
        lastCalledFunction = "deposit";
    }

    function encode() external pure returns(bytes memory) {
        return abi.encodeWithSignature("deposit()");
    }

}