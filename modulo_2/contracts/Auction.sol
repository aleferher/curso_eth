// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/// @title Contrato de Subasta con depósitos, comisión y reembolsos parciales
/// @author Alejandro Fernandez Herrero
/// @notice Implementa una subasta donde los participantes hacen ofertas con depósito.
///         Se extiende la subasta si se puja en los últimos 10 minutos.
///         Contempla comisión sobre la oferta ganadora y devolución de depósitos a no ganadores.
/// @dev Todos los pagos usan transferencia segura. Usa eventos para transparencia.
contract Auction {

    /// @notice Dirección del creador y propietario del contrato
    address public owner;

    /// @notice Timestamp donde finaliza la subasta
    uint public auctionEndTime;

    /// @notice Duración inicial de la subasta (en segundos)
    uint public initialDuration;

    /// @notice Incremento mínimo necesario para superar la mejor oferta en porcentaje (ejemplo: 5 = 5%)
    uint public bidIncreasePercent = 5;

    /// @notice Tiempo adicional a extender la subasta si la última oferta fue cerca del final (en segundos)
    uint public extensionTime = 10 minutes;

    /// @notice Porcentaje de comisión sobre el monto ganador que se paga al propietario
    uint public commissionRate = 2;

    /// @notice Información de cada oferta: oferente y monto
    struct Bid {
        address bidder;
        uint amount;
    }

    /// @notice Listado de todas las ofertas en orden cronológico
    Bid[] public bids;

    /// @notice Indica si la subasta ya fue finalizada
    bool public auctionEnded;

    /// @notice Dirección del ganador
    address public winner;

    /// @notice Monto de la oferta ganadora
    uint public winningBid;

    /// @notice Depósitos totales de cada participante
    mapping(address => uint) public deposits;

    /// @notice Evento emitido cuando un participante realiza una nueva oferta válida
    /// @param bidder Dirección del oferente
    /// @param amount Monto ofertado
    event NewBid(address indexed bidder, uint amount);

    /// @notice Evento emitido cuando se finaliza la subasta
    /// @param winner Dirección del ganador
    /// @param winningAmount Monto neto obtenido por el ganador (sin comisión)
    event AuctionEnded(address indexed winner, uint winningAmount);

    /// @notice Evento emitido cuando un no ganador recibe la devolución de su depósito
    /// @param bidder Dirección del participante reembolsado
    /// @param amount Monto devuelto
    event DepositRefunded(address indexed bidder, uint amount);

    /// @notice Evento emitido cuando un participante retira parte de su depósito durante la subasta
    /// @param bidder Dirección del participante
    /// @param amount Monto retirado
    event PartialWithdrawal(address indexed bidder, uint amount);

    /// @notice Modificador que restringe funciones solo para el propietario
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede ejecutar esta funcion");
        _;
    }

    /// @notice Modificador que solo permite ejecución mientras la subasta esté activa
    modifier auctionActive() {
        require(block.timestamp < auctionEndTime, "La subasta ha terminado");
        require(!auctionEnded, "La subasta ya fue finalizada");
        _;
    }

    /// @notice Modificador que solo permite ejecución después de finalizar la subasta
    modifier auctionEndedModifier() {
        require(block.timestamp >= auctionEndTime, "La subasta sigue activa");
        require(!auctionEnded, "La subasta ya fue finalizada");
        _;
    }

    /// @notice Modificador que verifica que una oferta sea válida segun aumento mínimo
    /// @param bidAmount Monto ofertado
    modifier validBidAmount(uint bidAmount) {
        if (bids.length > 0) {
            uint minRequired = bids[bids.length - 1].amount * (100 + bidIncreasePercent) / 100;
            require(bidAmount >= minRequired, "Oferta debe ser al menos 5% mayor a la mejor oferta");
        } else {
            require(bidAmount > 0, "La primera oferta debe ser mayor a cero");
        }
        _;
    }

    /// @notice Constructor que inicializa la subasta con duración en minutos y establece propietario
    /// @param _durationInMinutes Duración en minutos de la subasta
    constructor(uint _durationInMinutes) {
        owner = msg.sender;
        initialDuration = _durationInMinutes * 1 minutes;
        auctionEndTime = block.timestamp + initialDuration;
    }

    /// @notice Función para realizar una nueva oferta válida con pago adjunto
    function placeBid() external payable auctionActive validBidAmount(msg.value) {
        // Registrar oferta
        Bid memory newBid = Bid(msg.sender, msg.value);
        bids.push(newBid);

        // Actualizar estado ganador
        winner = msg.sender;
        winningBid = msg.value;

        // Extender subasta si la oferta fue en últimos 10 minutos
        if (block.timestamp > auctionEndTime - extensionTime) {
            auctionEndTime += extensionTime;
        }

        // Actualizar depósito acumulado para el participante
        deposits[msg.sender] += msg.value;

        emit NewBid(msg.sender, msg.value);
    }

    /// @notice Devuelve la lista de todas las ofertas realizadas
    /// @return Array de ofertas con estructra Bid
    function getAllBids() public view returns (Bid[] memory) {
        return bids;
    }

    /// @notice Devuelve el ganador y monto final, solo si la subasta terminó
    /// @return Dirección ganadora y monto de la oferta ganadora
    function getWinner() public view returns (address, uint) {
        require(auctionEnded, "La subasta no ha finalizado");
        return (winner, winningBid);
    }

    /// @notice Permite retirar el exceso de depósito durante o después de la subasta
    /// El exceso es lo que el participante ha depositado sobre su última oferta válida ganadora
    function withdrawExcess() external {
        require(deposits[msg.sender] > 0, "No hay fondos a retirar");
        uint excess;
        if (!auctionEnded) {
            // Durante la subasta, el exceso es el total depositado menos la última oferta válida (si la tiene)
            uint lastBidAmount = 0;
            for (uint i = bids.length; i > 0; i--) {
                if (bids[i-1].bidder == msg.sender) {
                    lastBidAmount = bids[i-1].amount;
                    break;
                }
            }
            require(deposits[msg.sender] > lastBidAmount, "No hay exceso a retirar");
            excess = deposits[msg.sender] - lastBidAmount;
            deposits[msg.sender] = lastBidAmount;
        } else {
            // Tras finalizar, el exceso es todo el depósito si no fue ganador
            if (msg.sender == winner) {
                revert("El ganador no puede retirar exceso");
            }
            excess = deposits[msg.sender];
            deposits[msg.sender] = 0;
            require(excess > 0, "No hay fondos a retirar");
        }
        payable(msg.sender).transfer(excess);
        emit PartialWithdrawal(msg.sender, excess);
    }

    /// @notice Permite al propietario finalizar la subasta y distribuir los fondos
    function finalizeAuction() external onlyOwner auctionEndedModifier {
        require(bids.length > 0, "No hay ofertas para finalizar");

        auctionEnded = true;

        winner = bids[bids.length - 1].bidder;
        winningBid = bids[bids.length - 1].amount;

        // Comision al dueño
        uint commission = (winningBid * commissionRate) / 100;
        // Transferir comisión
        payable(owner).transfer(commission);

        // Reembolsar depósitos a no ganadores
        for (uint i = 0; i < bids.length; i++) {
            address bidder = bids[i].bidder;
            if (bidder != winner && deposits[bidder] > 0) {
                uint refundAmount = deposits[bidder];
                deposits[bidder] = 0;
                payable(bidder).transfer(refundAmount);
                emit DepositRefunded(bidder, refundAmount);
            }
        }

        emit AuctionEnded(winner, winningBid - commission);
    }

    /// @notice Permite al propietario retirar la oferta ganadora neta de comisión a una dirección destino
    /// @param _destination Dirección que recibirá los fondos ganadores
    function withdrawMainBid(address _destination) external onlyOwner {
        require(auctionEnded, "La subasta no ha finalizado");
        uint commission = (winningBid * commissionRate) / 100;
        uint payout = winningBid - commission;
        payable(_destination).transfer(payout);
    }
}
