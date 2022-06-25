// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./imports/ERC721Enumerable.sol";
import "./imports/Ownable.sol";
import "./imports/ERC2981.sol";
import "./imports/IERC20.sol";
import "./imports/IERC721Enumerable.sol";
import "./imports/IWrappedFantom.sol";
import "./imports/Discounts.sol";
import "./imports/HandleRandomNumbers.sol";


/* Custom Error Section - Use with ethers.js for custom errors */
/*
* @dev Public Mint is Paused
*/
error MintPaused();

/*
* @dev Cannot mint zero NFTs
*/
error AmountLessThanOne();

/* 
* @dev Cannot mint more than maxMintAmount
* @param amtMint - Amount the user is attempting to mint
* @param maxMint - Maximum amount allowed to be minted by user per transaction
*/
error AmountOverMax(uint256 amtMint, uint256 maxMint);

/*
* @dev Token not in Auth List
*/
error TokenNotAuthorized();

/*
* @dev Not enough mints left for mint amount
* @param supplyLeft - Number of tokens left to be minted
* @param amtMint    - Number of tokens user is attempting to mint
*/
error NotEnoughMintsLeft(uint256 supplyLeft, uint256 amtMint);

/*
* @dev Not enough ftm sent to mint
* @param totalCost - Cost of the NFTs to be minted
* @param amtFTM    - Amount being sent by the user
*/
error InsufficientFTM(uint256 totalCost, uint256 amtFTM);

contract BBG2V2 is ERC721Enumerable, Ownable, ERC2981 {
  using Strings for uint256;

  /*
  * @dev This struct holds information for the team member address and percent share
  * @item memberAddress - Address of team member (address)
  * @item memberShare   - Share of the team member (uint256)
  */
  struct TeamAndShare {
    address memberAddress;
    uint256 memberShare;
  }

  /*
  * Maps an index to a team member's information stored in a TeamAndShare struct
  */
  mapping(uint => TeamAndShare) public indexOfTeamMembers;

  /*
  * Maps a collection address to a discount
  * Discounts must be (100-intendDiscount),
  * i.e. If expected discount is 30%, uint value must be 70
  */
  mapping(address => uint) public collectionsWithDiscount;

  /*
  * Maps an ERC20 address to a price
  * Prices are set in ether
  * To set in ethers.js, use ethers.utils.parseUnits(priceToSet, 'ether')
  */
  //@audit cost too low?
  mapping(address => uint) public acceptedCurrencies;

  IWrappedFantom wftm;
  address public lpPair;
  string baseURI;
  string public baseExtension = ".json";
  uint256 public immutable maxSupply;
  uint256 public immutable maxMintAmount;
  bool public publicPaused = true;
  uint16[] private ids;
  uint16 private index = 0;
  uint public numberOfTeamMembers;
  address public immutable  partner = 0x0000000000000000000000000000000000000000;
  address public immutable bbg1 = 0x70e6d946bBD73531CeA997C28D41De9Ba52Ac905;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    address _lpPair,
    address _royaltyAddress,
    address _wftm,
    uint _royaltiesPercentage,
    uint _maxSupply,
    uint _maxMintAmount
  ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        ids = new uint16[](_maxSupply);
        maxMintAmount = _maxMintAmount;
        lpPair = _lpPair;
        wftm = IWrappedFantom(_wftm);
        _setReceiver(_royaltyAddress);
        setBaseURI(_initBaseURI);
        _setRoyaltyPercentage(_royaltiesPercentage);
  }

  /**** Begin external/public functions ****/
  /**** Setters to prepare the contract for mint ****/

  /*
  * @dev Set a new baseURI for the collection 
  * @param _newBaseURI - string uri to set, generally an IPFS address
  */
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  /*
  * @dev Pause/Unpause the mint
  * @param _state - Sets state of mint. True to paused; False to unpaused
  */
  function pausePublic(bool _state) public onlyOwner {
    publicPaused = _state;
  }
  
  /**** End functions for mint prep ****/

  /**** Functions used during mint/after setup ****/
  /*
  * @dev Mint one or many NFTs with a specific token and potential discount
  * @param _token      - Token address to be used for payment
  * @param _amount     - Amount of tokens to be minted
  * @param _collection - NFT collection address used for potential discount.
  *                      If no discount, set to zero address
  */
  function mint(address _token, uint _amount, address _collection, uint[] memory bbid, uint[] memory pid) external payable {
    //mint is closed
    if(publicPaused)
      revert MintPaused();
    if(_amount <= 0)
      revert AmountLessThanOne();
    //require(amount > 0, 'Cannot mint 0');
    if(_amount > maxMintAmount) {
      revert AmountOverMax({
        amtMint: _amount,
        maxMint: maxMintAmount
      });
    }
    if(acceptedCurrencies[_token] == 0)
      revert TokenNotAuthorized();
    //require(acceptedCurrencies[token] > 0, "token not authorized");

    require(_amount == bbid.length && _amount == pid.length, "array lengths do not match amount");
    while (bbid.length > 0) {
      IERC721Enumerable(bbg1).safeTransferFrom(msg.sender, address(this), bbid[bbid.length-1]);
      require(IERC721Enumerable(partner).ownerOf(pid[bbid.length-1]) == msg.sender, "does not own all partner nfts");
      delete bbid[bbid.length-1];
    }

    uint256 supply = totalSupply();
    if(supply + _amount > maxSupply) {
      revert NotEnoughMintsLeft({
        supplyLeft: maxSupply - supply,
        amtMint: _amount
      });
    }

    //All check have passed, we can mint after applying a discount to the cost
    //This function can be left in as long as Discount.sol is imported. 
    uint discountPercentage = _getDiscount(_collection);
    //If no discount, then returned discount percentage is zero. We need to return 100 in order to have the math cancel out to cost * 1

    uint amountFromSender = msg.value;
    if (_token == address(wftm)) {
        if(amountFromSender != _amount * acceptedCurrencies[address(wftm)] * discountPercentage / 100)
          revert InsufficientFTM({
            totalCost: _amount * acceptedCurrencies[address(wftm)] * discountPercentage / 100,
            amtFTM: amountFromSender
          });
        //require(msg.value == amount * acceptedCurrencies[address(wftm)], "insufficient ftm");
        wftm.deposit{ value: amountFromSender }();
        _mintInternal(_amount);
    } else {
        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount * acceptedCurrencies[_token] * discountPercentage / 100), "Payment not successful");
        _mintInternal(_amount);
    }

  }

  /*
  * @dev Very basic, mostly unomptimized batchTransfer function - could maybe add unchecked to save some gas.
  * @param _from - Address that NFTs will be transfered from
  * @param _to - Address that NFTs will be transfered to
  * @param _tokenIds - Array of token IDs to be received by to
  */
  function batchTransfer(address _from, address _to, uint256[] calldata _tokenIds) external {
    uint len = _tokenIds.length;
    for(uint i = 0; i < len; i++) {
      safeTransferFrom(_from, _to, _tokenIds[i]);
    }
  }

  /*
  * @dev Allow batch send to multiple addresses
  *      If you want to send to fewer addresses than tokenIds, just use the same addresses multiple times for the token Ids you want send send
  *      For example:
  *      tokenIds = [1, 3, 4, 6, 7]
  *      You need a to array length of 5 for the function to work. If you want to send to two people, you just use those two addresses in the correct tokenId locations.
  *      to = [0x0, 0x0, 0x1, 0x1, 0x0]
  * 
  * @param _from     - Address that NFTs will be transfered from
  * @param _to       - Array of addresses that NFTs will be transfered to
  * @param _tokenIds - Array of token IDs to be received by to
  */
  function batchTransferManyAddresses(address _from, address[] calldata _to, uint256[] calldata _tokenIds) external {
    require(_to.length == _tokenIds.length, "Tokens not being sent to enough addresses");
    uint len = _tokenIds.length;
    for(uint i = 0; i < len; i++) {
      safeTransferFrom(_from, _to[i], _tokenIds[i]);
    }
  }

  /*
  * @dev Returns the token IDs owned by _owner
  * @param _owner - Address of NFT owner
  */
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

  /*
  * @dev Returns the URI based on tokenID
  * @param tokenID - Token ID to query for URI value
  */
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

  /*
  * @dev Returns the supported interfaces
  * @param _interfaceID - bytes4 value which represents a contract type
  */
  function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721Enumerable, IERC165, ERC165Storage) returns (bool) {
    return super.supportsInterface(_interfaceId);
  }
  
  /**** End Exteral/Public Functions ****/

  /**** Internal function calls ****/
  
  /*
  * @dev Returns the baseURI for the collection
  */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  /*
  * @dev Picks a random ID to mint based on an input random number
  * @param _random - Random number to use as seed for ID pick
  */
  function _pickRandomUniqueId(uint256 _random) internal returns (uint256 id) {
      uint256 len = ids.length - index++;
      require(len > 0, "no ids left");
      uint256 randomIndex = _random % len;
      id = ids[randomIndex] != 0 ? ids[randomIndex] : randomIndex;
      ids[randomIndex] = uint16(ids[len - 1] == 0 ? len - 1 : ids[len - 1]);
      ids[len - 1] = 0;
  }

  //@Audit - Is there a way to move this to a library?
  /*
  * @dev Evaluates the collection address passed and returns a percentDiscount based on the preset discounts, or gives no discount
  * @param _collection - Address of the NFT collection being used for a discount
  */
  function _getDiscount(address _collection) internal view returns(uint percentDiscount) {
    uint noDiscount;
    if(_collection == address(0)) {
      noDiscount = 100;
    }
    else if(ERC721(_collection).balanceOf(msg.sender) > 0) {
      require(collectionsWithDiscount[_collection] > 0, "NFT is not in accepted collection");
      percentDiscount = collectionsWithDiscount[_collection];
    }
    return Math.min(percentDiscount, noDiscount);
  }

  /*
  * @dev Internal mint function that handles the random ID check by calling _getRandom from library contracts.
  *      To increase randomization, we pass supply and lpPair. All external mints go through this function.
  *
  * @param _amount - Amount of NFTs to be minted
  */
  function _mintInternal(uint _amount) internal {
    uint supply = totalSupply();
    for (uint256 i = 1; i <= _amount; ++i) {
        _safeMint(msg.sender, _pickRandomUniqueId(HandleRandomNumbers._getRandom(supply, lpPair)) +1);
    }
  }


  /*
  * @dev This function adds a currency address at an input price, and allows for the mint to be done
  *      in multiple currencies.
  *      Prices are set in ether
  *      To set in ethers.js, use ethers.utils.parseUnits(priceToSet, 'ether'); 
  *
  * @param _acceptedCurrencyInput - Address of currency to be accepted for payment
  * @param _price                 - Price for payment mapped to address of _acceptedCurrencyInput
  */
  function _addCurrency(address _acceptedCurrencyInput, uint256 _price) internal {
    require(_acceptedCurrencyInput != address(0), "Cannot set zero address as currency");
    acceptedCurrencies[_acceptedCurrencyInput] = _price;
  }

  /*
  * @dev Set the team and share by passing an index of that team member for payment after mint
  * @param _teamAddress - Address of team member to pay out
  * @param _percentShare - Percent out of 100 to pay out to _teamAddress
  * @param _teamIndex    - Index of team member, starting from 0 through N-1 (N = total team members).
  *                        This is the withdraw function will access each member, so remember the order.
  */
  function _setTeamAndShares(address _teamAddress, uint256 _percentShare, uint256 _teamIndex) internal {
    require(_teamAddress != address(0), "Can't send money to burn address");
    indexOfTeamMembers[_teamIndex] = TeamAndShare(_teamAddress, _percentShare);
    numberOfTeamMembers++;
  }

  /*
  * @dev Sets the NFT collections that can apply a discount to the mint cost
  * @param _collectionAddress - Address of the collection to whitelist for discount
  * @param _discount          - Discount to be set. This number must be 100-expectedDiscountPercentage.
  */
  function _setDiscountCollections(address _collectionAddress, uint _discount) internal {
    require(_collectionAddress != address(0), "Cannot set zero address as collection");
    collectionsWithDiscount[_collectionAddress] = _discount;
  }

  /*
  * @dev Withdraws token from the contract and splits it among team members
  * @param _token - Token address corresponding to the token to be withdrawn from the contract
  */
  function _withdraw(address _token) internal {
    require(acceptedCurrencies[_token] > 0, "token not authorized");
    uint amount = IERC20(_token).balanceOf(address(this));
    require(amount > 0);
    
    if(_token == address(0)) {
        //This should only need to be called if a bug occurs and FTM (not wFTM) is sent to the contract
        payable(msg.sender).transfer(address(this).balance);
    }
    else {
      uint len = numberOfTeamMembers;
      TeamAndShare memory memberToBePaid;
      for(uint i = 0; i < len; i++) {
        memberToBePaid = indexOfTeamMembers[i];
        IERC20(_token).transfer(memberToBePaid.memberAddress, amount * memberToBePaid.memberShare / 100);
      }
    }
  }
}