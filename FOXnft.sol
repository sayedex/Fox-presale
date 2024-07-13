// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Foxeurope ERC721A OG GamerGirlz Smart Contract
/// @notice Serves as a fungible token
/// @dev Inherits the ERC721A implentation

contract FoxeuropeNFT is Ownable, ERC721A {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    //State Variables
    /// @notice Is tokenAddress
    address public token;
    /// @notice Is treasuryWallet
    address public treasuryWallet;
    /// @notice Is contract paused?
    bool public contractPaused;
    /// @notice Base URI of all NFTs on the contract
    string public baseTokenURI;
    /// @notice Maximum supply of NFTs in the contract
    uint256 public maxSupply;
    /// @notice Price of each NFT
    uint256 public price;

    // Events
    event Withdraw(uint256 amount, address indexed addr);

    // Constructor
    /// @dev Initializes the contract
    constructor(address _token)
        ERC721A("FoxeuropeNFT", "FOXF")
        Ownable(msg.sender)
    {
        maxSupply = 1000;
        price = 0.025 ether;
        token = _token;
        baseTokenURI = "";
        treasuryWallet = msg.sender;
    }

    // Modifiers
    /// @notice Modifier to check supply and price
    /// @param _num The number of NFTs to mint
    /// @param _checkPrice True or False to check the price
    /// @param _value Value in ETH passed
    modifier whenNotPausedAndValidSupply(
        uint256 _num,
        address _user,
        bool _checkPrice,
        uint256 _value
    ) {
        require(!contractPaused, "Sale Paused!");
        require(totalSupply() + _num <= maxSupply, "Max supply reached!");
        if (_checkPrice) {
            require(
                IERC20(token).balanceOf(_user) >= price * _num,
                "Not enough FOX sent, check price"
            );
        }
        _;
    }

    // External Functtions

    /// @notice Mint an NFT to a specified wallet. This is used by WERT CC payment
    /// @param _to Address of wallet to mint the NFT to
    /// @param _num The number of NFTs to mint
    /// @param _amount Total price for NFTs

    function mintTo(
        address _to,
        uint256 _num,
        uint256 _amount
    ) external whenNotPausedAndValidSupply(_num, msg.sender, true, _amount) {
        IERC20(token).safeTransferFrom(msg.sender, treasuryWallet, _amount);
        _safeMint(_to, _num);
    }

    /// @notice Change price of NFT - Testing purposes only, will be removed from production
    /// @param _price New NFT price
    function changePrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    /// @notice Change price of Supply of NFTs - Testing purposes only, will be removed from production
    /// @param _maxSupply New NFT supply
    function changeMaxSupply(uint256 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    /// @notice Change the base URI of all NFTs on the contract
    /// @param _baseTokenURI New NFT base URI
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    /// @notice Allows contract owner to pause the contract
    function pauseContract() external onlyOwner {
        contractPaused = true;
    }

    /// @notice Allows contract owner to unpause the contract
    function unpauseContract() external onlyOwner {
        contractPaused = false;
    }

    // @notice Function to update the treasuryWallet address
    function setTreasuryWallet(address _newTreasuryWallet) external onlyOwner {
        require(
            _newTreasuryWallet != address(0),
            "Invalid treasury wallet address"
        );
        treasuryWallet = _newTreasuryWallet;
    }

    /// @notice Allows owner to withdraw ETH balance
    function withdraw() external payable onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed.");

        emit Withdraw(amount, msg.sender);
    }

    /// @notice Returns the URI of the NFT
    /// @param _tokenId ID of the NFT
    /// @dev Returns the URI of the token
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        ".json"
                    )
                )
                : "";
    }

    // View Functions

    /// @notice Return the BaseURI of all NFTs on the contract
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /// @notice Internal function to start ID from 1
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /// @notice return the tokens owned by an address
    function walletOfOwner(address owner) public view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (
                uint256 i = _startTokenId();
                tokenIdsIdx != tokenIdsLength;
                ++i
            ) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }
}
