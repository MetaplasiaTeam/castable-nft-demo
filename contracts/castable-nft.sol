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


    // Mapping from tokenId to casting type(1.Ethereum,2.ERC20,3.ERC721);
    mapping(uint256 => uint256) private _tokenMintTyp;
    // Mapping from tokenId to uri
    mapping(uint256 => string) private _tokenURIs;
    // Mapping from tokenId to burnBlockNum
    mapping(uint256 => uint256) private _tokenBurnBlockNum;
    // Mapping from tokenId to casting value(wei);
    mapping(uint256 => uint256) private _tokenValues;
    // Mapping from tokenId to erc20 contract addresses;
    mapping(uint256 => address) private _erc20TokenAddrs;
    // Mapping from tokenId to erc721 contract addresses;
    mapping(uint256 => address) private _erc721TokenAddrs;


     struct Collectible {
        uint256 id;
        uint256 value;
        address addr;
        string  uri;
        
    }

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
        return _tokenURIs[_tokenId];
    }

    function totalSupply() public view returns (uint256) {
        return tokenCounter;
    }


    function getByOwner(address _owner) public view returns(Collectible[] memory) {
        Collectible[] memory collectibles = new Collectible[](balanceOf(_owner));
        uint256 counter;
        for (uint i = 0; i < tokenCounter; i++) {
            if (_owners[i] == _owner) {
                (address addr, uint256 value) = tokenValue(i);
                collectibles[counter] = Collectible(i,value,addr,_tokenURIs[i]);
                counter++;
            }
        }
        return collectibles;
    }


    function tokenValue(uint256 _tokenId) public view existToken(_tokenId) returns (address addr, uint256 value) {
        if (_tokenMintTyp[_tokenId] == 1) {
            addr = address(0);
        } else if (_tokenMintTyp[_tokenId] == 2) {
             addr = _erc20TokenAddrs[_tokenId];
        } else {
             addr = _erc721TokenAddrs[_tokenId];
        }
        value = _tokenValues[_tokenId];
    }

    function tokenBurnBlockNum(uint256 _tokenId) external view existToken(_tokenId) returns (uint256) {
        return _tokenBurnBlockNum[_tokenId];
    }

 
    function _create(string memory _uri) private returns (uint256)  {
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _tokenURIs[newItemId] = _uri;
        tokenCounter ++;
        return newItemId;
    }



    /**
     * @dev create a collection using the specified uri.
     */
    function mint(string memory _uri,uint256 _burnBlockNum) external payable returns (uint256) {
        require(msg.value >= minMintValue, "Less than the minimum casting value");
        uint256 newItemId = _create(_uri);
        _tokenValues[newItemId] = msg.value;
        _tokenBurnBlockNum[newItemId] = _burnBlockNum;
        _tokenMintTyp[newItemId] = 1;
        return newItemId;
    }

    /**
     * @dev create multiple collections with the same uri.
     */
    function mintAvg(string memory _uri, uint256 count,uint256 _burnBlockNum) external payable returns (uint256[] memory) {
        uint256[] memory ids = new uint[](count);
        uint256 avgValue = msg.value / count;
        require(avgValue >= minMintValue, "Less than the minimum casting value");
        for (uint256 i = 0; i < count; i++) {
            uint256 newItemId = _create(_uri);
            ids[i] = newItemId;
            _tokenValues[newItemId] = avgValue;
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 1;
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
    function mintCustom(string[] memory _uris, uint256[] memory _values,uint256 _burnBlockNum) external payable returns (uint256[] memory) {
        require(_uris.length == _values.length, "Inconsistent length");
        uint256 totalValue;
        for (uint256 i = 0; i < _values.length; i++) {
            require(_values[i] >= minMintValue, "Payable value must greater than _values!");
            totalValue += _values[i];
        }
        require(msg.value >= totalValue, "Payable value must greater than the sum of the custom values");


    uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            uint256 newItemId = _create(_uris[i]);
            ids[i] = newItemId;
            _tokenValues[newItemId] = _values[i];
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 1;
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
    function mintByERC20(address _addr, uint256 _value, string memory _uri,uint256 _burnBlockNum) external returns (uint256) {
        require(_value > 0, "Value must be greater than 0");
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= _value, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), _value), "Transfer failed!");

        uint256 newItemId = _create(_uri);
        _erc20TokenAddrs[newItemId] = _addr;
        _tokenValues[newItemId] = _value;
        _tokenBurnBlockNum[newItemId] = _burnBlockNum;
        _tokenMintTyp[newItemId] = 2;
        return newItemId;
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
    function mintByERC20Avg(address _addr, string memory _uri, uint256 _value, uint256 count,uint256 _burnBlockNum) external returns (uint256[] memory) {
        require(_value > 0, "Value must be greater than 0");
        IERC20 erc20Token = IERC20(_addr);
        require(erc20Token.allowance(msg.sender, address(this)) >= _value, "Insufficient allowance!");
        require(erc20Token.transferFrom(msg.sender, address(this), _value), "Transfer failed!");

        uint256[] memory ids = new uint[](count);
        uint256 avgValue = _value / count;
        require(avgValue > 0, "Avg value must be greater than 0");
        for (uint256 i = 0; i < count; i++) {
            uint256 newItemId = _create(_uri);
            _erc20TokenAddrs[newItemId] = _addr;
            _tokenValues[newItemId] = avgValue;
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 2;
            ids[i] = newItemId;
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
    function mintByERC20Custom(address _addr, string[] memory _uris, uint256[] memory _values,uint256 _burnBlockNum) external returns (uint256[] memory) {
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
            uint256 newItemId = _create(_uris[i]);
            _erc20TokenAddrs[newItemId] = _addr;
            _tokenValues[newItemId]= _values[i];
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 2;
            ids[i] = newItemId;
        }
        return ids;
    }



    /**
    * @dev create a collection minted using ERC721 tokens.
     *
     */
    function mintByERC721(address _addr, uint256 _id, string memory _uri,uint256 _burnBlockNum) external returns (uint256) {
        IERC721 erc721Token = IERC721(_addr);

        require(erc721Token.getApproved(_id) == address(this), "Contract is not approved for this erc721 token");
        erc721Token.transferFrom(msg.sender, address(this), _id);

  
        uint256 newItemId = _create(_uri);
        // add 1 here so that don't get cast if id = 0;
        _erc721TokenAddrs[newItemId] = _addr;
        _tokenValues[newItemId] = _id;
        _tokenBurnBlockNum[newItemId] = _burnBlockNum;
        _tokenMintTyp[newItemId] = 3;
        return newItemId;
    }

    /**
    * @dev create multiple collectibles minted using ERC721 tokens.
     *
     */
    function mintByERC721Custom(address _addr, string[] memory _uris, uint256[] memory _ids,uint256 _burnBlockNum) external returns (uint256[] memory) {
        
        IERC721 erc721Token = IERC721(_addr);
        uint256[] memory ids = new uint[](_uris.length);
        for (uint256 i = 0; i < _uris.length; i++) {
            require(erc721Token.getApproved(_ids[i]) == address(this), "Contract is not approved for this erc721 token");
            erc721Token.transferFrom(msg.sender, address(this), _ids[i]);

            uint256 newItemId = _create(_uris[i]);
            _erc721TokenAddrs[newItemId] = _addr;
            _tokenValues[newItemId] = _ids[i];
            _tokenBurnBlockNum[newItemId] = _burnBlockNum;
            _tokenMintTyp[newItemId] = 3;
            ids[i] = newItemId;
        }

        return ids;
    }


    /**
     * @dev burn collectibles returns the casting value(Ethereum,ERC720,ERC721 token value).
     */
    function burn(uint256 _tokenId) existToken(_tokenId) public {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: transfer caller is not owner nor approved");
        require(block.number >= _tokenBurnBlockNum[_tokenId], "It can be burned only when it reaches the designated block");
        _burn(_tokenId);

        if (_tokenMintTyp[_tokenId] == 1) {
            (bool sent,) = msg.sender.call{value : _tokenValues[_tokenId]}("");
            require(sent, "Failed to send Ether");
        } else if (_tokenMintTyp[_tokenId] == 2) {
            IERC20 erc20Token = IERC20(_erc20TokenAddrs[_tokenId]);
            erc20Token.transfer(msg.sender, _tokenValues[_tokenId]);
        } else {
            IERC721 erc721Token = IERC721(_erc721TokenAddrs[_tokenId]);
            erc721Token.safeTransferFrom(address(this), msg.sender, _tokenValues[_tokenId]);
        }
    }
}
