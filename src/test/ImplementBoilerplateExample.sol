// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "../BBG2V2.sol";

contract ImplementBoilerplateExample is BoilerplateERC721 {
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI, //""
        address _lpPair,
        address _royaltyAddress,
        address _wftm,
        uint _royaltiesPercentage,
        uint _maxSupply,
        uint _maxMintAmount
  ) BoilerplateERC721(_name, _symbol, _initBaseURI, _lpPair, _royaltyAddress, _wftm, _royaltiesPercentage, _maxSupply, _maxMintAmount) {}

  //Set overriding admin functions if you want them to be external and callable after deploying - this is better for contract optimization
  //Since they are internal, you could simply call the functions from this contract depending on your use case
  //@Audit - Do internal functions need to be onlyowner if the external function calling it is already onlyOwner?
  function _addCurrency(address _acceptedCurrencyInput, uint256 _price) internal override {
    require(_acceptedCurrencyInput != address(0), "Cannot set zero address as currency");
    acceptedCurrencies[_acceptedCurrencyInput] = _price;
  }

  function _setTeamAndShares(address _teamAddress, uint256 _percentShare, uint256 _teamIndex) internal override {
    require(_teamAddress != address(0), "Can't send money to burn address");
    indexOfTeamMembers[_teamIndex] = TeamAndShare(_teamAddress, _percentShare);
    numberOfTeamMembers++;
  }

  function _setDiscountCollections(address _collectionAddress, uint _discount) internal override {
    require(_collectionAddress != address(0), "Cannot set zero address as collection");
    collectionsWithDiscount[_collectionAddress] = _discount;
  }

  //External functions to be called after contract is deployed for this example case
  //These functions will call the overriding internal functions
  function addCurrency(address _acceptedCurrencyInput, uint256 _price) external onlyOwner {
      _addCurrency(_acceptedCurrencyInput, _price);
  }

  function setTeamAndShares(address _teamAddress, uint256 _percentShare, uint256 _teamIndex) external onlyOwner {
      _setTeamAndShares(_teamAddress, _percentShare, _teamIndex);
  }

  function setDiscountCollections(address _collectionAddress, uint _discount) external onlyOwner {
      _setDiscountCollections(_collectionAddress, _discount);
  }
}