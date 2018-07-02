pragma solidity 0.4.19;

contract RockPaperScissors{

//Player can enter an interger representative of the move (Rock = 1, Paper=2, Scissors = 3  encrypted by a password 
//a Wait time is then started for the next player to make a move.
//Once both players have made their moves, then 
//the players need to reveal their moves within appropriate Wait times.
//If either player does not reveal their move in the allocated Wait time, 
//then as a penalty 0.1Ether from his/her total balance is retained by the contract.
//If a reveal is made in time, then the winner takes away his own balance as well as 0.05Ether 
//from the opponent's balance. The opponent retains the other 0.05Ether

    struct Player {
        bytes32 hash;
        uint balances;
        bool active;
    }
    
    mapping (address => Player) public players;
    
    address[] activePlayerAddress;

    uint  public playTime;
    uint  public waitTime;
    uint  public winningMove;
    uint  public equalMove;
    uint  public contractBalance;
    bool  public running;
    address public savedAddress;
    address public owner;
    
    event LogResetGame(address player);
    event LogPlayerSubmittedMove (address player, uint amount, bytes32 hash);
    event LogPlayerRevealedMove  (address player, bytes32 hash, uint move);
    event LogWithdraw(address player, uint amount);
    event LogPaused(address owner, uint amount, bool currentState);

    modifier onlyIfRunning{
      require (running == true);
      _;
    }
    
    function RockPaperScissors(uint timeInSecs) public{
        waitTime = timeInSecs;
        playTime = now + waitTime;
        running = true;
        owner = msg.sender;
    }


    function makeSecretMove(bytes32 hash) public payable onlyIfRunning returns(bool success){
    // if previous game is over, then reset the game
       if(now > playTime){
         LogResetGame(msg.sender);
         resetGame();  
       }
    // if game has started (avoid just after reset), then check if playTime is not over
       if(playTime!= 0){
           require(now < playTime);
       }
    // do not allow same player to enter a second move until game is over
       require(!players[msg.sender].active);
    // wager per play is 0.1 ether
       require(msg.value >= 0.1 ether); 
    // only allow 2 players in a game 
       require(activePlayerAddress.length < 2); 
       activePlayerAddress.push(msg.sender);
    // After both players entered the game, 
    // 0.1 ether from each player is alloted to the contract balance initially, 
    // at the end of the game, winner gets back 0.15 ether from contract's balance
    // loser gets 0.05 ether from the contract's balance
    // if any player does not reveal in time, then his ether stays with the contract balance
    // the 'reveal'ed player gets back his 0.1 ether from the contract's balance
    // thus reveal returns atleast 50% of your deposit while on non-reveal returns 0%
       players[msg.sender].hash = hash;
       players[msg.sender].active = true;
    // set the balances in the first player's account incase second player doesnt turn up
       if(activePlayerAddress.length < 2){
        players[msg.sender].balances += msg.value;
        savedAddress = msg.sender; 
       }    
    // both players submitted move, now do balances management
       if(activePlayerAddress.length == 2){
        players[msg.sender].balances += (msg.value - 0.1 ether);
        players[savedAddress].balances -= 0.1 ether;
        contractBalance += 0.2 ether;
       }
       playTime = now + waitTime;
       LogPlayerSubmittedMove(msg.sender, msg.value, hash); 
       return true;
    }
    
    
    function reveal(bytes32 password, uint move) public onlyIfRunning returns(bool success){
       require(now < playTime);
       bytes32 hash = createMove(msg.sender, password, move);
       require(players[msg.sender].hash == hash);
     //Reveal only if both players have made a SecretMove earlier, 
       require(activePlayerAddress.length == 2);
       LogPlayerRevealedMove(msg.sender, hash, move); 
    // execute the below 'if' statements for the initial reveal in the game   
       if (winningMove == 0){
        // save the first revealing address for balance management later on    
           savedAddress = msg.sender;
        // return the 0.1ether from contract to the msg.sender as reveal is made   
           contractBalance -= 0.1 ether;
           players[msg.sender].balances += 0.1 ether;
        // reset the hash of the msg.sender and prevent duplicate reveal    
           players[msg.sender].hash = 0;
           players[msg.sender].active = false;
       }
    // execute the below 'if' statements for the second reveal in the game   
        if (winningMove != 0){
          if(move == winningMove){
              players[msg.sender].balances += 0.15 ether;
              players[savedAddress].balances -= 0.05 ether;
              contractBalance -= 0.1 ether;
          } 
          if(move != winningMove && move != equalMove){
              players[savedAddress].balances += 0.05 ether;
              players[msg.sender].balances += 0.05 ether;
              contractBalance -= 0.1 ether;
          } 
          if(move != winningMove && move == equalMove){
              players[msg.sender].balances += 0.1 ether;
              contractBalance -= 0.1 ether;
          } 
          players[msg.sender].hash = 0;
          players[msg.sender].active = false;
        }
       winningMove = getWinningMove(move);
       // save the first revealed move, to check if the second revealed move is the same
       equalMove = move;
       return true;
    }

    
    function resetGame() private{
           playTime = 0;
           winningMove = 0;
           savedAddress = 0;
           equalMove = 0;
           for (uint i=0; i<activePlayerAddress.length; i++){
               players[activePlayerAddress[i]].hash = 0;
               players[activePlayerAddress[i]].active = false;
           }
           delete activePlayerAddress;
     }

    
    //Enter numbers to represent move: Rock = 1, Paper = 2, Scissors = 3  
    //along with a password to encode the move
    function createMove(address account, bytes32 password, uint move) public pure returns(bytes32 hash){
        return keccak256(account, password, move);
    }

    
    function getWinningMove(uint move) private pure returns(uint winMove){
    // Rock = 1, Paper=2, Scissors = 3   
        if(move == 1 ) return 2;
        if(move == 2 ) return 3;
        if(move == 3 ) return 1;
    }
    
    
   function  withdraw() public onlyIfRunning returns (bool success){
      // withdrawal is possible if game is over
      // if the game has started, withdrawal possible only by an inactive player  
       if(now < playTime){
           require(!players[msg.sender].active);
       }
       uint amount = players[msg.sender].balances;
       players[msg.sender].balances -= amount;
       if (amount > 0) {
         LogWithdraw(msg.sender, amount);
         msg.sender.transfer(amount); 
      }
      return true;
    }
   

    function pause() public returns(bool success){
       require(msg.sender == owner);
       bool state = running;
       running = !state;
       uint amount = contractBalance;
       if(amount > 0){
           contractBalance -= amount;
           LogPaused(msg.sender, contractBalance, running);
           msg.sender.transfer(amount);
       }
       return true;
    }

    
    function() public{
       revert();
    }
  
    
}

