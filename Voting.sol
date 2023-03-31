pragma solidity ^0.8.0;

contract Voting {
    // Структура для хранения информации о кандидате
    struct Candidate {
        uint id; // идентификатор кандидата
        string name; // имя кандидата
        uint voteCount; // количество голосов за кандидата
    }

    // Структура для хранения информации об избирателе
    struct Voter {
        uint rank; // ранг избирателя от 1 до 10
        bool voted; // флаг, указывающий, проголосовал ли избиратель
        uint vote; // идентификатор кандидата, за которого проголосовал избиратель
    }

    // Структура для хранения информации об администраторе
    struct Admin {
        uint id; // идентификатор администратора
    }

    // Стадия голосования
    enum VotingStage {
        CandidatesAdding, //Добавление кандидитов
        Voting, // Голосование
        Ended // Голосование окончено
    }

    // Адрес владельца контракта
    address public owner;

    // Количество кандидатов
    uint public candidatesCount = 0;

    // Количество администраторов
    uint public adminsCount = 0;

    // Срок голосования в секундах
    uint public votingPeriod;

    // Время начала голосования
    uint public startTime;

    //Стадия голосования
    VotingStage public votingState;

    // Маппинг для хранения кандидатов по идентификаторам
    mapping(uint => Candidate) public candidates;

    // Маппинг для хранения избирателей по адресам
    mapping(address => Voter) public voters;

    // Маппинг для хранения админов по адресам
    mapping(address => Admin) public admins;

    // Событие, которое срабатывает при голосовании за кандидата
    event Voted(address voter, uint candidate);
    // Событие, которое срабатывает при объявлении победителя голосования
    event Winner(uint id, string name);
    // Событие, которое срабатывает при отсутсвии победителия голосования (ничья)
    event Tie(string message);

    // Модификатор для проверки, что вызывающий является владельцем контракта
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Модификатор для проверки, что вызывающий является админом
    modifier onlyAdmin() {
        require(admins[msg.sender].id > 0, "Only admins access level!");
        _;
    }

    // Модификатор для проверки, что в данный момент голосование находится в стадии добавления кандидатов
    modifier candidateAdding() {
        require(votingState == VotingStage.CandidatesAdding, "The list of candidates has already been formed");
        _;
    }

    // Модификатор для проверки, что в данный момент происходит стадия голосования
    modifier voting() {
        require(votingState == VotingStage.Voting, "The voting stage is currently underway");
        _;
    }

    // Конструктор контракта, принимающий конфигурируемые параметры
    constructor(uint _votingPeriod) {
        owner = msg.sender;
        votingPeriod = _votingPeriod;
        votingState = VotingStage.CandidatesAdding;
        addAdmin(owner);
    }

    function addAdmin(address admin) public onlyOwner {
        require(admins[admin].id == 0, "This admin already exist!");
        
        adminsCount = adminsCount + 1;
        admins[admin] = Admin(adminsCount);
    }

    function addCandidate(string memory name) public onlyAdmin candidateAdding {
        require(bytes(name).length > 0, "Invalid candidate name");
        
        candidatesCount = candidatesCount + 1;
        candidates[candidatesCount] = Candidate(candidatesCount, name, 0);
    }

    function startVotingStage() public candidateAdding onlyAdmin {
        votingState = VotingStage.Voting;
        startTime = block.timestamp;
    }

    function addVoter(address voter, uint rank) public onlyAdmin {
        require(rank > 0 && rank <= 10, "Invalid voter rank"); // проверяем, что ранг избирателя в допустимом диапазоне
        require(voters[voter].rank == 0, "Voter already exists"); // проверяем, что избиратель с таким адресом еще не добавлен

        voters[voter] = Voter(rank, false, 0); // создаем и добавляем избирателя в маппинг
    }

    function vote(uint candidate) public voting {
        require(block.timestamp < startTime + votingPeriod, "Voting period is over"); // проверяем, что срок голосования не истек
        require(candidate > 0 && candidate <= candidatesCount, "Invalid candidate id"); // проверяем, что идентификатор кандидата в допустимом диапазоне
        require(voters[msg.sender].rank > 0, "You are not a registered voter"); // проверяем, что вызывающий является зарегистрированным избирателем
        require(!voters[msg.sender].voted, "You have already voted"); // проверяем, что вызывающий еще не проголосовал

        voters[msg.sender].voted = true;
        voters[msg.sender].vote = candidate;
        candidates[candidate].voteCount += voters[msg.sender].rank;

        emit Voted(msg.sender, candidate); // генерируем событие о голосовании
    }

    function endVoting() public onlyAdmin voting {
        require(block.timestamp >= startTime + votingPeriod, "Voting period is not over yet"); // проверяем, что срок голосования истек
        require(votingState != VotingStage.Ended, "Voting has already ended"); // проверяем, что голосование еще не завершено

        votingState = VotingStage.Ended;

        uint maxVoteCount = 0;
        uint winner = 0;

        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > maxVoteCount) {
                maxVoteCount = candidates[i].voteCount;
                winner = i;
            }
        }

        if (winner > 0) {
            emit Winner(candidates[winner].id, candidates[winner].name);
        } else {
            emit Tie("No winner!");
        }
    }
}