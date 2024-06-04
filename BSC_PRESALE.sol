// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";

contract FOX_PRESALE is ReentrancyGuard, NonblockingLzApp {
    using SafeERC20 for IERC20;
    // uint256 public constant FIVE_MONTHS = 30 days * 5;
    // uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant FIVE_MONTHS = 10 minutes;
    uint256 public constant ONE_YEAR = 30 minutes;
    uint256 public PRESALE_START = 0;
    uint256 public PRESALE_ENDTIME = 0;
    uint256 constant TotalRound = 2;
    uint256 public totalSold;
    uint256 public totalRaised;
    uint256 public nextTokenId;

    address public treasuryWallet;

    address public taxwalletA;
    address public taxwalletB;

    struct PresaleRound {
        mapping(uint256 => uint256) tokenPrice;
        uint256 tokensSold;
        uint256 endTimestamp;
    }
    struct PaymentToken {
        address _tokenaddress;
        uint8 _decimals;
    }

    struct VestingRecord {
        uint256 amount;
        uint256 deadline;
        bool claimed;
    }

    struct WhiteListedUsers {
        uint256 Percentage;
        bool isWhiteListed;
        uint256 usdtPercentage;
    }

    struct User {
        uint256 tokenamount;
        uint256 referral;
    }

    struct VestingSchedule {
        uint256 immediateAmount;
        mapping(uint256 => VestingRecord) vestingRecords;
    }
    mapping(uint256 => PresaleRound) public presalePool;
    mapping(uint256 => PaymentToken) public tokenInfo;
    mapping(uint256 => uint256) public roundDeadline;
    mapping(uint256 => mapping(address => WhiteListedUsers))
        public WhiteListedUser;
    // for 1st pool its USDT - for 2nd pool its token amount
    mapping(uint256 => uint256) public refferTokenPercentage;
    mapping(uint256 => uint256) public refferUSDTPercentage;

    mapping(uint256 => uint256) public RoundVestingPercentage;
    mapping(address => User) private userToken;

    // team payment
    mapping(uint256 => mapping(address => bool)) public WhiteListedTaxUser;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(
        address _treasuryWallet,
        address _tokenAddress,
        address _taxwalletA,
        address _taxwalletB,
        address _lzEndpoint
    ) Ownable(msg.sender) NonblockingLzApp(_lzEndpoint) {
        treasuryWallet = _treasuryWallet;
        PRESALE_ENDTIME = block.timestamp + 10 minutes;
        PRESALE_START = block.timestamp;
        // reffer
        refferTokenPercentage[0] = 10;
        refferTokenPercentage[1] = 20;
        refferUSDTPercentage[0] = 10;
        refferUSDTPercentage[1] = 20;
        RoundVestingPercentage[0] = 30;
        RoundVestingPercentage[1] = 60;

        roundDeadline[0] = FIVE_MONTHS;
        roundDeadline[1] = ONE_YEAR;

        presalePool[0].tokenPrice[0] = 2000000000000000000;
        presalePool[1].tokenPrice[0] = 2000000000000000000;

        taxwalletA = _taxwalletA;
        taxwalletB = _taxwalletB;

        // set payment token
        require(_tokenAddress != address(0), "Invalid token address");
        tokenInfo[nextTokenId] = PaymentToken({
            _tokenaddress: _tokenAddress,
            _decimals: IERC20Metadata(_tokenAddress).decimals()
        });
        nextTokenId++;
    }


    function buyTokensA(uint256 _tokenId, uint256 _tokenAmount,       address _referrer)
        external
        nonReentrant
    {
        uint256 _poolId = 0;
        uint256 amountTokens = (presalePool[0].tokenPrice[_tokenId] *
            _tokenAmount) / 10**tokenInfo[_tokenId]._decimals;

        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            msg.sender,
            address(this),
            _tokenAmount
        );
        _processPayment_pool_1(msg.sender,_tokenId,_tokenAmount,_poolId,_referrer);

        // send layerzero request here..
    }



    function _processPayment_pool_1(
        address _buyer,
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _poolId,
        address _referrer
    ) internal {
        uint256 _amount;
        uint256 _referrerAmount;

        if (_referrer == address(0)) {
            _amount = _tokenAmount;
        } else {
            if (WhiteListedUser[_poolId][_referrer].isWhiteListed) {
                _referrerAmount =
                    (_tokenAmount *
                        WhiteListedUser[_poolId][_referrer].Percentage) /
                    100;
            } else {
                _referrerAmount =
                    (_tokenAmount * refferUSDTPercentage[_poolId]) /
                    100;
            }

            _amount = _tokenAmount - _referrerAmount;

            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                _referrer,
                _referrerAmount
            );
        }

        if (!WhiteListedTaxUser[_poolId][_buyer]) {
            uint256 _tax1 = (_amount * 6) / 100;
            uint256 _tax2 = (_amount * 14) / 100;
            _amount = _amount - (_tax1 + _tax2);
            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                taxwalletA,
                _tax1
            );

            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                taxwalletA,
                _tax2
            );
        }

        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            address(this),
            treasuryWallet,
            _amount
        );
    }

    function _processPayment_pool_2(
        address _buyer,
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _poolId,
        address _referrer
    ) internal {
        uint256 _amount;
        uint256 _reffer_usdt;

        if (_referrer == address(0)) {
            _amount = _tokenAmount;
        } else {
            if (WhiteListedUser[_poolId][_referrer].isWhiteListed) {
                _reffer_usdt =
                    (_tokenAmount *
                        WhiteListedUser[_poolId][_referrer].usdtPercentage) /
                    100;
            } else {
        
                _reffer_usdt =
                    (_tokenAmount * refferUSDTPercentage[_poolId]) /
                    100;
            }
            _amount = _tokenAmount - _reffer_usdt;
            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                _referrer,
                _reffer_usdt
            );
        }

        if (!WhiteListedTaxUser[_poolId][_buyer]) {
            uint256 _tax1 = (_amount * 6) / 100;
            uint256 _tax2 = (_amount * 14) / 100;
            _amount = _amount - (_tax1 + _tax2);
            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                taxwalletA,
                _tax1
            );

            transferCurrency(
                tokenInfo[_tokenId]._tokenaddress,
                address(this),
                taxwalletA,
                _tax2
            );
        }

        transferCurrency(
            tokenInfo[_tokenId]._tokenaddress,
            msg.sender,
            treasuryWallet,
            _amount
        );
    }

  



    function _nonblockingLzReceive(
        uint16,
        bytes memory,
        uint64,
        bytes memory _payload
    ) internal virtual override {
        (address _user, uint256 _amount) = abi.decode(
            _payload,
            (address, uint256)
        );
    }

    function setPresaleEndTime(uint256 _PRESALE_ENDTIME) external onlyOwner {
        require(block.timestamp < _PRESALE_ENDTIME, "time short");
        PRESALE_ENDTIME = _PRESALE_ENDTIME;
    }

    function setPresaleStartTime(uint256 _PRESALE_START) external onlyOwner {
        require(block.timestamp > _PRESALE_START, "time short");
        PRESALE_START = _PRESALE_START;
    }

    function setPaymentToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        tokenInfo[nextTokenId] = PaymentToken({
            _tokenaddress: _tokenAddress,
            _decimals: IERC20Metadata(_tokenAddress).decimals()
        });
        nextTokenId++;
    }

    function setPrice(
        uint256 _poolId,
        uint256 _tokenId,
        uint256 _price
    ) external onlyOwner {
        presalePool[_poolId].tokenPrice[_tokenId] = _price;
    }

    function withdrawEther(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    function setTreasuryWallet(address _newTreasuryWallet) external onlyOwner {
        require(
            _newTreasuryWallet != address(0),
            "Invalid treasury wallet address"
        );
        treasuryWallet = _newTreasuryWallet;
    }

    function setTaxWalletA(address _taxwalletA) external onlyOwner {
        require(
            _taxwalletA != address(0),
            "Invalid _taxwalletA wallet address"
        );
        taxwalletA = _taxwalletA;
    }

    function setTaxWalletB(address _taxwalletB) external onlyOwner {
        require(
            _taxwalletB != address(0),
            "Invalid _taxwalletB wallet address"
        );
        taxwalletB = _taxwalletB;
    }

    function setRefferTokenPercentage(uint256 _poolId, uint256 value)
        external
        onlyOwner
    {
        refferTokenPercentage[_poolId] = value;
    }

    function setRefferUSDTPercentage(uint256 _poolId, uint256 value)
        external
        onlyOwner
    {
        refferUSDTPercentage[_poolId] = value;
    }

    function setWhiteListedUser(
        uint256 _poolId,
        address _user,
        uint256 _percentage,
        bool _isWhiteListed,
        uint256 _percentageusdt
    ) external onlyOwner {
        WhiteListedUser[_poolId][_user] = WhiteListedUsers({
            Percentage: _percentage,
            isWhiteListed: _isWhiteListed,
            usdtPercentage: _percentageusdt
        });
    }

    function setWhiteListedTaxUser(
        uint256 _poolId,
        address _user,
        bool value
    ) external onlyOwner {
        WhiteListedTaxUser[_poolId][_user] = value;
    }

    /// @dev Transfers a given amount of currency.
    function transferCurrency(
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }
        safeTransferERC20(_currency, _from, _to, _amount);
    }

    // @dev Transfer `amount` of ERC20 token from `from` to `to`.
    function safeTransferERC20(
        address _currency,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        if (_from == _to) {
            return;
        }

        if (_from == address(this)) {
            IERC20(_currency).safeTransfer(_to, _amount);
        } else {
            IERC20(_currency).safeTransferFrom(_from, _to, _amount);
        }
    }

    receive() external payable {}

    function getUserpurchase(address user)
        external
        view
        returns (uint256, uint256)
    {
        return (userToken[user].tokenamount, userToken[user].referral);
    }
}
