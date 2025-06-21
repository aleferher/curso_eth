// SPDX-License-Identifier: MIT

pragma solidity >=0.8.28;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MyToken - Un token ERC20 personalizado para proyectos inmobiliarios con capacidades de acuñación y quema de tokens
/// @author 
/// @notice Este contrato emite un token ERC20, permite acuñar por el owner y quemar por los titulares.
/// @dev Basado en OpenZeppelin ERC20
contract Aureo is ERC20, Ownable {
    
    /// @notice Constructor que crea el token y asigna la emisión inicial al deployer
    /// @param initialSupply Cantidad inicial de tokens a emitir (en unidades enteras, no en wei del token)
    constructor(uint256 initialSupply) ERC20("Aureo", "AUR") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    /// @notice Permite al propietario acuñar tokens adicionales
    /// @dev Solo puede ser llamado por el owner del contrato
    /// @param to Dirección que recibirá los tokens
    /// @param amount Cantidad de tokens a acuñar (en wei del token, es decir, con decimales)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Permite a cualquier titular de tokens quemar parte de sus propios tokens
    /// @dev Reduce el totalSupply y el saldo del emisor
    /// @param amount Cantidad de tokens a quemar (en wei del token, es decir, con decimales)
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /// @notice Devuelve la cantidad total de tokens emitidos en unidades legibles (sin decimales)
    /// @dev Equivale a `totalSupply() / 10**decimals()`
    /// @return totalTokensEmitidos Cantidad de tokens emitidos en unidades enteras
    function tokensEmitidos() public view returns (uint256 totalTokensEmitidos) {
        return totalSupply() / (10 ** decimals());
    }

    function puedeQuemar(address usuario, uint256 amount) public view returns (bool) {
        return balanceOf(usuario) >= amount;
    }

}