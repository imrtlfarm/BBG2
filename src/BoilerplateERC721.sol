// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC2981.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./interfaces/IWrappedFantom.sol";
import "./lib/Discounts.sol";
import "./lib/HandleRandomNumbers.sol";


/* Custom Error Section - Use with ethers.js for custom errors */
// Public Mint is Paused
error MintPaused();

// Cannot mint zero NFTs
error AmountLessThanOne();

// Cannot mint more than maxMintAmount
error AmountOverMax(uint256 amtMint, uint256 maxMint);

// Token not in Auth List
error TokenNotAuthorized();

// Not enough mints left for mint amount
error NotEnoughMintsLeft(uint256 supplyLeft, uint256 amtMint);

// Not enough ftm sent to mint
error InsufficientFTM(uint256 totalCost, uint256 amtFTM);

abstract contract BoilerplateERC721 is ERC721Enumerable, Ownable, ERC2981 {
  using Strings for uint256;

  struct TeamAndShare {
    address memberAddress;
    uint256 memberShare;
  }

  mapping(uint => TeamAndShare) private indexOfTeamMembers;

  mapping(address => uint) public collectionsWithDiscount;

  //@audit cost too low?
  mapping(address => uint) public acceptedCurrencies;

  IWrappedFantom wftm;// = IWrappedFantom(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
  address public lpPair; // = 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c; - usdcftm pair
  address public addressLGE;
  address private treasuryAddress;
  string baseURI;
  string public baseExtension = ".json";
  uint256 public immutable maxSupply; //2000
  uint256 public immutable maxMintAmount; //5
  bool public publicPaused = true;
  uint16[2000] private ids;
  uint16 private index = 0;
  uint private numberOfTeamMembers;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI, //""
    address _treasuryAddress,
    address _lpPair,
    address _royaltyAddress,
    address _addressLGE,
    address _wftm,
    uint _royaltiesPercentage,
    uint _maxSupply,
    uint _maxMintAmount
  ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        maxMintAmount = _maxMintAmount;
        treasuryAddress = _treasuryAddress;
        addressLGE = _addressLGE;
        lpPair = _lpPair;
        wftm = IWrappedFantom(_wftm);
        _setReceiver(_royaltyAddress);
        setBaseURI(_initBaseURI);
        _setRoyaltyPercentage(_royaltiesPercentage);
  }

  /* Begin external/public functions */
  /* Setters to prepare the contract for mint */
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function pausePublic(bool _state) public onlyOwner {
    publicPaused = _state;
  }
  /* End functions for mint prep */

  /* Functions used during mint/after setup */
  function mint(address token, uint amount, address collection) external payable {
    //mint is closed
    if(publicPaused)
      revert MintPaused();
    if(amount <= 0)
      revert AmountLessThanOne();
    //require(amount > 0, 'Cannot mint 0');
    if(amount > maxMintAmount) {
      revert AmountOverMax({
        amtMint: amount,
        maxMint: maxMintAmount
      });
    }
    if(acceptedCurrencies[token] == 0)
      revert TokenNotAuthorized();
    //require(acceptedCurrencies[token] > 0, "token not authorized");

    uint256 supply = totalSupply();
    if(supply + amount > maxSupply) {
      revert NotEnoughMintsLeft({
        supplyLeft: maxSupply - supply,
        amtMint: amount
      });
    }

    //All check have passed, we can mint after applying a discount to the cost
    //This function can be left in as long as Discount.sol is imported. 
    uint discountPercentage = _getDiscount(collection, addressLGE);
    //If no discount, then returned discount percentage is zero. We need to return 100 in order to have the math cancel out to cost * 1

    uint amountFromSender = msg.value;
    if (token == address(wftm)) {
        if(amountFromSender != amount * acceptedCurrencies[address(wftm)] * discountPercentage / 100)
          revert InsufficientFTM({
            totalCost: amount * acceptedCurrencies[address(wftm)] * discountPercentage / 100,
            amtFTM: amountFromSender
          });
        //require(msg.value == amount * acceptedCurrencies[address(wftm)], "insufficient ftm");
        wftm.deposit{ value: amountFromSender }();
        _mintInternal(amount);
    } else {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount * acceptedCurrencies[token] * discountPercentage / 100), "Payment not successful");
        _mintInternal(amount);
    }

  }

  //Very basic, mostly unomptimized batchTransfer function - could maybe add unchecked to save some gas.
  function batchTransfer(address from, address to, uint256[] calldata tokenIds) external {
    uint len = tokenIds.length;
    for(uint i = 0; i < len; i++) {
      transferFrom(from, to, tokenIds[i]);
    }
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165, ERC165Storage) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
  /* End Exteral/Public Functions */

  /* Internal function calls */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function _pickRandomUniqueId(uint256 _random) internal returns (uint256 id) {
      uint256 len = ids.length - index++;
      require(len > 0, "no ids left");
      uint256 randomIndex = _random % len;
      id = ids[randomIndex] != 0 ? ids[randomIndex] : randomIndex;
      ids[randomIndex] = uint16(ids[len - 1] == 0 ? len - 1 : ids[len - 1]);
      ids[len - 1] = 0;
  }

  //@Audit - Is there a way to move this to a library?
  function _getDiscount(address collection, address LGEAddress) internal returns(uint percentDiscount) {
    //First check if they have 50% discount from LGE
    //only need to return 1 of the two values. Both will be 0 if not participated
    IElasticLGE LGEContract = IElasticLGE(LGEAddress);
    uint lgePercentDiscount = 100;
    Terms memory termReturn = LGEContract.terms(msg.sender);
    if(collection == address(0)) {
      percentDiscount = 100;
    }
    else if(ERC721(collection).balanceOf(msg.sender) > 0) {
      require(collectionsWithDiscount[collection] > 0, "NFT is not in accepted collection");
      percentDiscount = collectionsWithDiscount[collection];
    }
    if(termReturn.term > 0) {
      lgePercentDiscount = 100 - Discounts._curve(termReturn.term);
    }
    else {
      lgePercentDiscount = 100;
    }
    return Math.min(percentDiscount, lgePercentDiscount);
  }

  function _mintInternal(uint _amount) internal {
    uint supply = totalSupply();
    for (uint256 i = 1; i <= _amount; ++i) {
        _safeMint(msg.sender, _pickRandomUniqueId(HandleRandomNumbers._getRandom(supply, lpPair)) +1);
    }
  }

  //This function adds a currency address at a given price point
  //Allows for multiple currencies to be 
  function _addCurrency(address _acceptedCurrencyInput, uint256 _price) internal {
    require(_acceptedCurrencyInput != address(0), "Cannot set zero address as currency");
    acceptedCurrencies[_acceptedCurrencyInput] = _price;
  }

  function _setTeamAndShares(address _teamAddress, uint256 _percentShare, uint256 _teamIndex) internal {
    require(_teamAddress != address(0), "Can't send money to burn address");
    indexOfTeamMembers[_teamIndex] = TeamAndShare(_teamAddress, _percentShare);
    numberOfTeamMembers++;
  }

  function _setDiscountCollections(address _collectionAddress, uint _discount) internal {
    require(_collectionAddress != address(0), "Cannot set zero address as collection");
    collectionsWithDiscount[_collectionAddress] = _discount;
  }

  function _withdraw(address token) internal {
    require(acceptedCurrencies[token] > 0, "token not authorized");
    uint amount = IERC20(token).balanceOf(address(this));
    require(amount > 0);
    
    if(token == address(0)) {
        //This should only need to be called if a bug occurs and FTM (not wFTM) is sent to the contract
        payable(msg.sender).transfer(address(this).balance);
    }
    else {
      uint len = numberOfTeamMembers;
      TeamAndShare memory memberToBePaid;
      for(uint i = 0; i < len; i++) {
        memberToBePaid = indexOfTeamMembers[i];
        IERC20(token).transfer(memberToBePaid.memberAddress, amount * memberToBePaid.memberShare / 100);
      }
    }
  }
}