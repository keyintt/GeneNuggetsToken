pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';

/**
 * @title Gene Nuggets Token
 *
 * @dev Implementation of the Gene Nuggets Token.
 */
contract GeneNuggetsToken is Pausable,StandardToken {
  using SafeMath for uint256;
  
  string public name = "Gene Nuggets Token";
  string public symbol = "GNUT";
   
  //constants
  uint8 public decimals = 6;
  uint256 public decimalFactor = 10 ** uint256(decimals);
  uint public CAP = 30e8 * decimalFactor; //Maximal GTN supply = 3 billion
  
  //contract state
  uint256 public circulatingSupply;
  uint256 public totalUsers;
  uint256 public injectLimit = 10000*decimalFactor;
  uint256 public injectThreshold = 100*decimalFactor;
  uint256 public injectInterval = 60;
  uint256 public extractThreshold = 100*decimalFactor;
 
  //managers address
  address public CFO; //CFO address
  mapping(address => uint256) public CustomerService; //customer service addresses
  
  //mining rules
  uint[10] public MINING_LAYERS = [0,10e4,30e4,100e4,300e4,600e4,1000e4,2000e4,3000e4,2**256 - 1];
  uint[9] public MINING_REWARDS = [1000*decimalFactor,600*decimalFactor,300*decimalFactor,200*decimalFactor,180*decimalFactor,160*decimalFactor,60*decimalFactor,39*decimalFactor,0];
  
  //events
  event Mine(uint totalUser,uint totalSupply);
  event Inject(address indexed user,uint256 amount);
  event Extract(address indexed user,uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  modifier onlyCFO() {
    require(msg.sender == CFO);
    _;
  }

  modifier nonZeroAddress(address a){
    require(a != address(0));
    _;
  }

  modifier onlyCustomerService() {
    require(CustomerService[msg.sender] != 0);
    _;
  }

  /**
  * @dev ccontract constructor
  */  
  function GeneNuggetsToken() public {}

  /**
  * @dev fallback revert eth transfer
  */   
  function() public {
    revert();
  }
  
  /**
   * @dev Allows the current owner to change token name.
   * @param newName The name to change to.
   */
  function setName(string newName) external onlyOwner {
    name = newName;
  }
  
  /**
   * @dev Allows the current owner to change token symbol.
   * @param newSymbol The symbol to change to.
   */
  function setSymbol(string newSymbol) external onlyOwner {
    symbol = newSymbol;
  }
  
  /**
   * @dev Allows the current owner to change CFO address.
   * @param newCFO The address to change to.
   */
  function setCFO(address newCFO) external onlyOwner nonZeroAddress(newCFO){
    CFO = newCFO;
  }
  
  /**
   * @dev Allows owner to change injectInterval.
   * @param newInterval The new interval to change to.
   */
  function setInjectInterval(uint newInterval) external onlyOwner {
    injectInterval = newInterval;
  }

  /**
   * @dev Allows owner to change injectLimit.
   * @param newLimit The new limit to change to.
   */
  function setInjectLimit(uint newLimit) external onlyOwner {
    injectLimit = newLimit;
  }

  /**
   * @dev Allows owner to change injectThreshold.
   * @param newThreshold The new threshold to change to.
   */
  function setInjectThreshold(uint newThreshold) external onlyOwner {
    injectThreshold = newThreshold;
  }
  
  /**
   * @dev Allows owner to change extractThreshold.
   * @param newThreshold The new threshold to change to.
   */
  function setExtractThreshold(uint newThreshold) external onlyOwner {
    extractThreshold = newThreshold;
  }
  
  /**
   * @dev Allows CFO to add customer service address.
   * @param cs The address to add.
   */
  function addCustomerService(address cs) onlyCFO nonZeroAddress(cs) external {
    CustomerService[cs] = block.timestamp;
  }
  
  /**
   * @dev Allows CFO to remove customer service address.
   * @param cs The address to remove.
   */
  function removeCustomerService(address cs) onlyCFO external {
    CustomerService[cs] = 0;
  }

  /**
   * @dev Function to allow CFO mine tokens according to user amount.Attention: newly mined token still outside contract until injected on user's requirments.  
   * @param _userAmount current gene nuggets user amount.
   */
  function mine(uint256 _userAmount) onlyCFO external {
    require(_userAmount>totalUsers);
    uint newTotalSupply = calTotalSupply(_userAmount);
    require(newTotalSupply<=CAP && newTotalSupply>totalSupply_);
    
    uint _amount = newTotalSupply.sub(totalSupply_);
    totalSupply_ = newTotalSupply;
    totalUsers = _userAmount;
    Mine(_amount,totalSupply_); 
  }

  /**
   * @dev Uitl function to calculate total supply according to total user amount.
   * @param _userAmount total user amount.
   */  
  function calTotalSupply(uint _userAmount) private view returns (uint ret) {
    uint tokenAmount = 0;
	  for (uint8 i = 0; i < MINING_LAYERS.length ; i++ ) {
	    if(_userAmount < MINING_LAYERS[i+1]) {
	      tokenAmount = tokenAmount.add(MINING_REWARDS[i].mul(_userAmount.sub(MINING_LAYERS[i])));
	      break;
	    }else {
        tokenAmount = tokenAmount.add(MINING_REWARDS[i].mul(MINING_LAYERS[i+1].sub(MINING_LAYERS[i])));
	    }
	  }
	  return tokenAmount;
  }

  /**
   * @dev Function for Customer Service exchange off-chain points to GNT on user's behalf. That is to say inject GNT into this contract.
   * @param user The user tokens distributed to.
   * @param _amount The amount of tokens to exchange.
   */
  function inject(address user,uint256 _amount) whenNotPaused onlyCustomerService external {
  	
  	require((block.timestamp-CustomerService[msg.sender])>injectInterval);

  	require(_amount <= injectLimit && _amount >= injectThreshold);

    circulatingSupply = circulatingSupply.add(_amount);
    
    balances[user] = balances[user].add(_amount);
    
    CustomerService[msg.sender] = block.timestamp;
    
    Inject(user,_amount);
    
    Transfer(address(0),user,_amount);
    
  }
  

  /**
   * @dev Function for user can exchange GNT back to off-chain points.That is to say extract GNT out of this contract.
   * @param _amount The amount of tokens to exchange.
   */
  function extract(uint256 _amount) external {  
    require(balances[msg.sender]>=_amount && _amount>extractThreshold && circulatingSupply>=_amount);

    circulatingSupply = circulatingSupply.sub(_amount);
    
    balances[msg.sender] = balances[msg.sender].sub(_amount);
    
    Extract(msg.sender,_amount);
    
    Transfer(msg.sender,0x0,_amount);
    
  }

  function emergencyERC20Drain( ERC20 token, uint amount ) onlyOwner {
    // owner can drain tokens that are sent here by mistake
    token.transfer( owner, amount );
  }
  
}