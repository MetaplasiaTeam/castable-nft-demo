// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/MetaplasiaTeam/castable-nft/blob/main/constracts/ERC721/IERC721Castable.sol";
// npm install @openzeppelin-contracts required

interface IERC20 {
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

}

contract CastableNFT is ERC721, Ownable,IERC721Castable {
    uint256 public tokenCounter;
    uint256 public  minMintValue;


    struct Collectible {
        // collectible id
        uint256 id;
        // 1.Ethereum,2.ERC20,3.ERC721
        uint256 mintTyp;
        // Ethereum,erc20 token value or erc721 id
        uint256 value;
        // burn timestamp allowed
        uint256 burnTime;
        // erc20,erc721 addr,default 0x
        address addr;
        // collectible uri
        string  uri;
    }

    // Mapping from tokenId to collectible;
    mapping(uint256 => Collectible) private _collectibles;



    constructor()  ERC721 ("Castable NFT", "CASTABLE") {
        tokenCounter = 0;
    }

    modifier existToken(uint256 _tokenId) {
        require(_exists(_tokenId), "Nonexistent token!");
        _;
    }

    function setMinMintValue(uint256 _value) external onlyOwner {
        minMintValue = _value;
    }

    function tokenURI(uint256 _tokenId) public view override existToken(_tokenId) returns (string memory) {
        return _collectibles[_tokenId].uri;
    }

    function totalSupply() public view returns (uint256) {
        return tokenCounter;
    }


    function get(uint256 _tokenId) public view existToken(_tokenId) returns(Collectible memory) {
        return _collectibles[_tokenId];
    }

    function getByOwner(address _owner) public view returns(Collectible[] memory) {
        Collectible[] memory collectibles = new Collectible[](balanceOf(_owner));
        uint256 counter;
        for (uint i = 0; i < tokenCounter; i++) {
            if (_owners[i] == _owner) {
                collectibles[counter] =  _collectibles[i];
                counter++;
            }
        }
        return collectibles;
    }


    function tokenValue(uint256 _tokenId) public view existToken(_tokenId) returns (address addr, uint256 value) {
        Collectible memory collectible =  _collectibles[_tokenId];
        addr = collectible.addr;
        value = collectible.value;
    }

 
    function _create(uint256 _mintTyp,string memory _uri,uint256 _value,address _addr,uint256 _burnTime) private returns (uint256)  {
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _collectibles[newItemId] = Collectible(newItemId,_mintTyp,_value,_burnTime,_addr,_uri);
        tokenCounter ++;
        return newItemId;
    }



    /**
     * @dev create a collection using the specified uri.
     */
    function mint(string memory _uri,uint256 _burnTime) external payable returns (uint256) {
        require(msg.value >= minMintValue, "Less than the minimum casting value");
        return _create(1,_uri,msg.value,address(0), _burnTime);
    }

    /**
     * @dev create multiple collections with the same uri.
     */
    function mintAvg(string memory _uri, uint256 count,uint256 _burnTime) external payable returns (uint256[] memory) {
        uint256[] memory ids = new uint[](count);
        uint256 avgValue = msg.value / count;
        require(avgValue >= minMintValue, "Less than the minimum casting value");
        for (uint256 i = 0; i < count; i++) {
            ids[i] = _create(1,_uri,avgValue,address(0), _burnTime);
        }
        return ids;
    }


    /**
     * @dev create multiple collectibles specified casting value and uri.
     *
     * Requirements:
     *
     * payable value needs to be greater than or equal to the sum of `_values`.
     *
     */
    function mintCustom(string[] memory _uris, uint256[] memory _values,uint256 _burnTime) external payable returns (uint256[] memory) {
        require(_uris.length == _values.length, "Inconsistent length");
        uint256 totalValue;
        for (uint256 i = 0; i < _values.length; i++) {
            require(_values[i] >= minMintValue, "Less than the minimum casting value");
            totalValue += _values[i];
        }
        require(msg.value >= totalValue, "Payable value must greater than the sum of the custom values");


        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            ids[i] =_create(1,_uris[i],_values[i],address(0), _burnTime);

        }
        return ids;
    }



    /**
    * @dev create a collection minted using erc20 tokens.
     *
     * Requirements:
     *
     * senders need to sets `_castingValue` amount as the allowance of this contract 
     * in ERC20 token in advance.
     *
     */
    function mintByERC20(address _addr, uint256 _value, string memory _uri,uint256 _burnTime) external returns (uint256) {
        require(_value > 0, "Value must be greater than 0");
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= _value, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), _value), "Transfer failed!");
        return _create(2,_uri,_value,_addr, _burnTime);
    }

    /**
    * @dev create multiple collectibles minted using erc20 tokens.
     * each collectible has the same uri and the cast value is equally distributed.
     *
     * Requirements:
     *
     * senders need to sets `_castingValue` amount as the allowance of this contract
     * in ERC20 token in advance.
     *
     */
    function mintByERC20Avg(address _addr, string memory _uri, uint256 _value, uint256 count,uint256 _burnTime) external returns (uint256[] memory) {
        require(_value > 0, "Value must be greater than 0");
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= _value, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), _value), "Transfer failed!");

        uint256[] memory ids = new uint[](count);
        uint256 avgValue = _value / count;
        require(avgValue > 0, "Avg value must be greater than 0");
        for (uint256 i = 0; i < count; i++) {
            ids[i] = _create(2,_uri,avgValue,_addr, _burnTime);
        }
        return ids;
    }

    /**
     * @dev create multiple collectibles minted using erc20 tokens.
     * each collectible has specified uri and casting value.
     *
     * Requirements:
     *
     * senders need to sets the sum of `_values` as the allowance to this contract
     * in ERC20 token in advance.
     *
     */
    function mintByERC20Custom(address _addr, string[] memory _uris, uint256[] memory _values,uint256 _burnTime) external returns (uint256[] memory) {
        require(_uris.length == _values.length, "Inconsistent length");
        uint256 totalValue;
        for (uint256 i = 0; i < _values.length; i++) {
            require(_values[i] > 0, "Value must be greater than 0");
            totalValue += _values[i];
        }
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= totalValue, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), totalValue), "Transfer failed!");



        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            ids[i] = _create(2,_uris[i],_values[i],_addr, _burnTime);
        }
        return ids;
    }



    /**
    * @dev create a collection minted using ERC721 tokens.
     *
     */
    function mintByERC721(address _addr, uint256 _id, string memory _uri,uint256 _burnTime) external returns (uint256) {
        IERC721 erc721Token = IERC721(_addr);

        require(erc721Token.getApproved(_id) == address(this), "Contract is not approved for this erc721 token");
        erc721Token.transferFrom(msg.sender, address(this), _id);

        return  _create(3,_uri,_id,_addr, _burnTime);
    }

    /**
    * @dev create multiple collectibles minted using ERC721 tokens.
     *
     */
    function mintByERC721Custom(address _addr, string[] memory _uris, uint256[] memory _ids,uint256 _burnTime) external returns (uint256[] memory) {
        
        IERC721 erc721Token = IERC721(_addr);
        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            require(erc721Token.getApproved(_ids[i]) == address(this), "Contract is not approved for this erc721 token");
            erc721Token.transferFrom(msg.sender, address(this), _ids[i]);

            ids[i] = _create(3,_uris[i],_ids[i],_addr, _burnTime);
        }

        return ids;
    }


    /**
     * @dev burn collectibles returns the casting value(Ethereum,ERC720 token value,ERC721 id).
     */
    function burn(uint256 _tokenId) existToken(_tokenId) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: transfer caller is not owner nor approved");
        Collectible memory collectible = _collectibles[_tokenId];
        require(block.timestamp >= collectible.burnTime, "It can be burned only when it reaches the designated block");
        _burn(_tokenId);

        if (collectible.mintTyp == 1) {
            (bool sent,) = msg.sender.call{value : collectible.value}("");
            require(sent, "Failed to send Ether");
        } else if (collectible.mintTyp == 2) {
            IERC20 erc20Token = IERC20(collectible.addr);
            erc20Token.transfer(msg.sender,collectible.value);
        } else {
            IERC721 erc721Token = IERC721(collectible.addr);
            erc721Token.safeTransferFrom(address(this), msg.sender,collectible.value);
        }
    }
}
