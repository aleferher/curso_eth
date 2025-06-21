// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Donation {
    uint256 expires;
    address foundation;
    mapping(address => uint) donations;
    bool donationClosed;

    constructor(address _foundation, uint256 duration) {
        foundation = _foundation;
        expires = block.timestamp + duration;
    }

    function claim() external {
        require(block.timestamp > expires);
        require(!donationClosed);
        require(donations[msg.sender] > 0);
        (bool result, ) = msg.sender.call{value: donations[msg.sender]}("");
        require(result);
        donations[msg.sender] = 0;
    }

    // la donacion tiene un tiempo de vida y si no se devuelve la plata
    
    // El minimo de donacion es 1 gwei y el maximo es 1 ether

    // La fundacion espera una donacion de 5 ether

    // El contrato tiene que tener una cuenta con permisos de administracion

    // Cuando se alcanza el objetivo se transfiere el total y se bloquean las donaciones

    // Si la ultima donacion se pasa, hay que dar el vuelto

}