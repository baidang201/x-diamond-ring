// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CyberDiamondRing is ERC721, Ownable, ReentrancyGuard {
    // 状态变量
    uint256 private _tokenIds;
    uint256 public constant MINT_PRICE = 10 ether;
    uint256 public constant BUYBACK_DISCOUNT = 990; // 9.9折 (990/1000)
    uint256 public constant BUYBACK_DENOMINATOR = 1000;
    uint256 public constant MIN_YEARS_FOR_BUYBACK = 10; // 最少持有10年才能回购
    
    // 存储每个tokenId对应的伴侣信息
    struct CoupleInfo {
        string partner1;
        string partner2;
        uint256 timestamp;
    }
    
    mapping(uint256 => CoupleInfo) public coupleInfos;
    mapping(address => bool) public hasMinted;
    
    // 事件
    event DiamondRingCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string partner1,
        string partner2,
        uint256 timestamp
    );
    
    event DiamondRingBuyback(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 buybackAmount,
        uint256 holdingPeriod
    );
    
    // constructor() ERC721("Cyber Diamond Ring", "CDR") Ownable() ReentrancyGuard() {}
    constructor() 
        ERC721("Cyber Diamond Ring", "CDR") 
        Ownable(msg.sender)  // 关键修正点
    {
        // ReentrancyGuard 自动初始化
    }

    
    // 铸造函数
    function mintDiamondRing(string memory partner1, string memory partner2) 
        external 
        payable 
        nonReentrant 
    {
        require(msg.value == MINT_PRICE, "Need exactly 10 ETH");
        require(!hasMinted[msg.sender], "Already minted");
        require(bytes(partner1).length > 0 && bytes(partner2).length > 0, "Names cannot be empty");
        
        // 销毁ETH
        (bool success, ) = address(0).call{value: msg.value}("");
        require(success, "ETH burn failed");
        
        // 铸造NFT
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        _safeMint(msg.sender, newTokenId);
        
        // 记录伴侣信息
        coupleInfos[newTokenId] = CoupleInfo({
            partner1: partner1,
            partner2: partner2,
            timestamp: block.timestamp
        });
        
        hasMinted[msg.sender] = true;
        
        emit DiamondRingCreated(
            newTokenId,
            msg.sender,
            partner1,
            partner2,
            block.timestamp
        );
    }
    
    // 9.9折回购接口，要求NFT创建时间超过10年
    function buybackDiamondRing(uint256 tokenId) 
        external 
        nonReentrant 
    {
        address owner = _ownerOf(tokenId);
        require(owner == msg.sender, "Not the owner");
        require(_exists(tokenId), "Token does not exist");
        
        CoupleInfo memory info = coupleInfos[tokenId];
        uint256 creationTime = info.timestamp;
        
        // 计算持有时间（以秒为单位）
        uint256 holdingPeriod = block.timestamp - creationTime;
        
        // 检查是否持有超过10年 (10年 = 10 * 365 * 24 * 60 * 60 秒)
        uint256 tenYearsInSeconds = 10 * 365 * 24 * 60 * 60;
        require(holdingPeriod >= tenYearsInSeconds, "Must hold for at least 10 years");
        
        // 计算9.9折回购金额
        uint256 buybackAmount = (MINT_PRICE * BUYBACK_DISCOUNT) / BUYBACK_DENOMINATOR;
        
        // 销毁NFT
        _burn(tokenId);
        
        // 转账ETH给用户
        (bool success, ) = payable(msg.sender).call{value: buybackAmount}("");
        require(success, "ETH transfer failed");
        
        emit DiamondRingBuyback(
            tokenId,
            msg.sender,
            buybackAmount,
            holdingPeriod
        );
    }
    
    // 获取伴侣信息
    function getCoupleInfo(uint256 tokenId) 
        external 
        view 
        returns (string memory partner1, string memory partner2, uint256 timestamp) 
    {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        CoupleInfo memory info = coupleInfos[tokenId];
        return (info.partner1, info.partner2, info.timestamp);
    }

    // 获取已铸造的NFT总数
    function getTotalMinted() 
        public 
        view 
        returns (uint256) 
    {
        return _tokenIds;
    }
    
    // 检查NFT是否可以回购（是否已经超过10年）
    function isEligibleForBuyback(uint256 tokenId)
        public
        view
        returns (bool)
    {
        require(_exists(tokenId), "Token does not exist");
        
        CoupleInfo memory info = coupleInfos[tokenId];
        uint256 creationTime = info.timestamp;
        
        // 计算持有时间（以秒为单位）
        uint256 holdingPeriod = block.timestamp - creationTime;
        
        // 检查是否持有超过10年 (10年 = 10 * 365 * 24 * 60 * 60 秒)
        uint256 tenYearsInSeconds = 10 * 365 * 24 * 60 * 60;
        return holdingPeriod >= tenYearsInSeconds;
    }
    
    // 重写tokenURI函数,返回元数据
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        require( _ownerOf(tokenId) != address(0), "Token does not exist");
        // 这里可以返回一个包含钻戒图片和信息的URI
        // 实际部署时需要实现具体的元数据逻辑
        return "";
    }
    
    // 合约需要接收ETH以支持回购功能
    receive() external payable {}
}
