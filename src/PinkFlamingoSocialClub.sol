// SPDX-License-Identifier: MIT
// File: contracts/PinkFlamingoSocialClub.sol

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PinkFlamingoSocialClub is ERC721Enumerable {
  /**
  @dev events
 */
  event Mint(address indexed _to, uint256 indexed _tokenId);
  event Migration(address indexed _to, uint256 indexed _tokenId);

  /**
  @dev global
 */
  address public admin;
  address public router;
  uint256 public nextTokenId = 1;
  uint256 public maxMint;
  uint256 public tokenPriceInWei;
  string public baseURI;
  bool public isMintPaused = true;
  /**
  @dev minters store
 */
  mapping(uint256 => address) public tokenIdToMinterAddress;

  /**
  @dev constructor
 */

  constructor(
    string memory _tokenName,
    string memory _tokenSymbol,
    address _router,
    uint256 _maxMint,
    uint256 _tokenPriceInWei
  ) ERC721(_tokenName, _tokenSymbol) {
    admin = msg.sender;
    maxMint = _maxMint;
    router = _router;
    tokenPriceInWei = _tokenPriceInWei;
  }

  /**
  @dev modifiers
 */

  modifier onlyValidTokenId(uint256 _tokenId) {
    require(_exists(_tokenId), 'Token ID does not exist Yet');
    _;
  }

  modifier onlyAdmin() {
    require(msg.sender == admin, 'Only admin');
    _;
  }

  /**
  @dev helpers 
 */
  function _splitFunds() internal {
    if (msg.value > 0) {
      uint256 refund = msg.value - tokenPriceInWei;
      if (refund > 0) {
        payable(msg.sender).transfer(refund);
      }
      payable(admin).transfer(tokenPriceInWei);
    }
  }

  function pauseMint() public onlyAdmin {
    isMintPaused = !isMintPaused;
  }

  function addBaseURI(string memory _newBaseURI) public onlyAdmin {
    baseURI = _newBaseURI;
  }

  function contractURI() public pure returns (string memory) {
    return
      string(
        'https://gateway.pinata.cloud/ipfs/QmPHQECr5EdhTgeWDjKJL7VNcSsFgrTeTVTgFtLpKmNbaA'
      );
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    override
    onlyValidTokenId(_tokenId)
    returns (string memory)
  {
    return string(abi.encodePacked(baseURI, '/nfts/', Strings.toString(_tokenId)));
  }

  /**
  @dev Mint Functions
 */

  function _mintToken(address _to) internal returns (uint256 _tokenId) {
    uint256 tokenIdToBe = nextTokenId;
    nextTokenId += 1;
    _mint(_to, tokenIdToBe);
    tokenIdToMinterAddress[tokenIdToBe] = _to;
    emit Mint(_to, tokenIdToBe);
    return tokenIdToBe;
  }

  function mintFlamingo() public payable returns (uint256 _tokenId) {
    return mintFalmingoTo(msg.sender);
  }

  function mintFalmingoTo(address _to) public payable returns (uint256 _tokenId) {
    require(msg.value >= tokenPriceInWei, 'Must send at least current price for token');
    require(nextTokenId <= maxMint, 'Must not exceed maximum mint on Fantom');
    require(!isMintPaused || msg.sender == admin, 'Purchases must not be paused');
    uint256 tokenId = _mintToken(_to);
    _splitFunds();
    return tokenId;
  }

  /**
    @dev anySwap
     */

  function updateRouter(address _router) external onlyAdmin {
    router = _router;
  }

  function _safeMigrationMint(
    address _router,
    uint256 _tokenId,
    address _to
  ) internal {
    _safeMint(_router, _tokenId);
    emit Migration(_to, _tokenId);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) public virtual override (ERC721, IERC721) {
    if (_msgSender() == router && from == router && to != router && !_exists(tokenId)) {
      require(tokenId > 0, 'Token ID invalid');
      _safeMigrationMint(router, tokenId, to);
    }
    require(
      _isApprovedOrOwner(_msgSender(), tokenId),
      'ERC721: transfer caller is not owner nor approved'
    );
    _safeTransfer(from, to, tokenId, data);
  }
}