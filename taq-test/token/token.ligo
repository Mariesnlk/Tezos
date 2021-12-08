//объявляем псевдоним trusted типа address. Мы будем использовать его для обозначения адресов, которые могут пересылать токены с контракта
type trusted is address;

//объявляем псевдоним amt (amount) типа nat для хранения балансов
type amt is nat;

(* объявляем псевдоним account типа record. В нем будем хранить данные пользователей, которым можно передавать токены.
*)
type account is
 record [
   balance         : amt;
   allowances      : map (trusted, amt);
 ]

(* объявляем тип хранилища смарт-контракта. Он хранит общее количество токенов, а также big_map,
который связывает публичные адреса и данные account пользователей *)
type storage is
 record [
   totalSupply     : amt;
   ledger          : big_map (address, account);
 ]

(* объявляем псевдоним для метода return, который будем использовать для возвращения операций. В коротких контрактах можно обойтись без него.
Но в контрактах с несколькими псевдо-точками входа проще один раз прописать тип возврата и использовать его для каждой функции *)
type return is list (operation) * storage

(* объявляем пустой список noOperations. Его будет возвращать метод return *)
const noOperations : list (operation) = nil;

(* объявляем псевдонимы входящих параметров для каждой базовой функции FA1.2 *)
type transferParams is michelson_pair(address, "from", michelson_pair(address, "to", amt, "value"), "")
type approveParams is michelson_pair(trusted, "spender", amt, "value")
type balanceParams is michelson_pair(address, "owner", contract(amt), "")
type allowanceParams is michelson_pair(michelson_pair(address, "owner", trusted, "spender"), "", contract(amt), "")
type totalSupplyParams is (unit * contract(amt))

(* псевдо-точки входа *)
type entryAction is
 | Transfer of transferParams
 | Approve of approveParams
 | GetBalance of balanceParams
 | GetAllowance of allowanceParams
 | GetTotalSupply of totalSupplyParams

(* функция getAccount получает входящий параметр типа address и значение storage из смарт-контракта.
Это функция-помощник: ее вызывают другие функции контракта для получения данных о пользователе, а пользователь не может вызвать ее напрямую *)
function getAccount (const addr : address; const s : storage) : account is
 block {
     // присваиваем переменной acct значение типа account: нулевой баланс и пустую запись allowances
   var acct : account :=
     record [
       balance    = 0n;
       allowances = (map [] : map (address, amt));
     ];

   (* проверяем, есть ли в хранилище аккаунт пользователя. Если нет — оставляем в acct пустое значение из предыдущего блоа.
   Если есть — присваиваем его переменной acct. Функция возвращает запись acct *)
   case s.ledger[addr] of
     None -> skip
   | Some(instance) -> acct := instance
   end;
 } with acct

(* getAllowance запрашивает у пользователя разрешение отрпавить токены из его адреса.
Она получает адрес пользователя, адрес контракта spender и состояние хранилища *)
function getAllowance (const ownerAccount : account; const spender : address; const _s : storage) : amt is
 (* если пользователь разрешил отправить некоторое количество токенов, функция присваивает это количество переменной amt.
 Если не разрешил — количество токенов равняется нулю *)
 case ownerAccount.allowances[spender] of
   Some (amt) -> amt
 | None -> 0n
 end;

(* Функция Transfer получает от пользователя адреса отправителя и получателя, количество токенов для перевода и состояние хранилища *)
function transfer (const from_ : address; const to_ : address; const value : amt; var s : storage) : return is
 block {

   (* вызываем фукнцию getAccount, чтобы присвоить ей данные аккаунта пользователя.
   Затем мы используем senderAccount чтобы считывать баланс пользователя и разрешения *)
   var senderAccount : account := getAccount(from_, s);

   (* проверяем, есть ли у пользователя достаточно средств для перевода.
   Если нет — виртуальная машина прерывает исполнение контракта, если есть — продолжает исполнять контракт *)
   if senderAccount.balance < value then
     failwith("NotEnoughBalance")
   else skip;

   (* проверяем, может ли адрес-инициатор транзакции отправить токены.
   Если адрес-инициатор запрашивает перевод из чужого адреса, функция запрашивает разрешение у настоящего владельца. Если инциатор и отправитель — один адрес, виртуальная машина продолжает исполнять контракт *)
   if from_ =/= Tezos.sender then block {
   (* вызываем функцию getAllowance, чтобы владелец адреса-отправителя указал, сколько токенов он разрешает отправить.
   Присваиваем это значение константе spenderAllowance *)
     const spenderAllowance : amt = getAllowance(senderAccount, Tezos.sender, s);

   (* если владелец разрешил отправить меньше токенов, чем указано во входящем параметре, виртуальная машина прекратит исполнять контракт *)
     if spenderAllowance < value then
       failwith("NotEnoughAllowance")
     else skip;

     (* отнимаем от разрешенного для отправки количества токенов сумму транзакции *)
     senderAccount.allowances[Tezos.sender] := abs(spenderAllowance - value);
   } else skip;

   (* отнимаем от баланса адреса-отправителя количество отправленных токенов *)
   senderAccount.balance := abs(senderAccount.balance - value);

   (* обновляем запись о балансе отправителя в storage *)
   s.ledger[from_] := senderAccount;

   (* еще раз вызываем функцию getAccount, чтобы получить или создать запись аккаунта для адреса-получателя *)
   var destAccount : account := getAccount(to_, s);

   (* добавляем к балансу получателя количество отправленных токенов *)
   destAccount.balance := destAccount.balance + value;

   (* обновляем запись о балансе получателя в storage *)
   s.ledger[to_] := destAccount;

 }
 // возвращаем пустой список операций и состояние storage после исполнения функции
 with (noOperations, s)

(* функция Approve запрашивает подверждение на количество токенов, которое адрес-ицинатор может отправить из адреса пользователей  *)
function approve (const spender : address; const value : amt; var s : storage) : return is
 block {

   (* получаем данные аккаунта-иницатора *)
   var senderAccount : account := getAccount(Tezos.sender, s);

   (* получаем текущее количество токенов, которое пользователь разрешил отправить *)
   const spenderAllowance : amt = getAllowance(senderAccount, spender, s);

   (* защищаем контракт от атаки с опережающим расходованием. Допустим, пользователь изменяет разрешенное количество токенов для отправки с 20 до 10.
   Владелец адреса-инициатора может об этом узнать и создать транзакцию с расходованием 20 токенов.
   Если он оплатит повышеннуюю комиссию, то эта транзакция попадет в блок раньше, чем пользователь изменит разрешенное количество токенов.
   По обновлении разрешения владелец адреса-инициатора создаст еще одну транзакцию на 10 токенов.
   В результате он отправит из адреса пользователя 30 токенов вместо 10. Чтобы такого не случилось, разработчики добавляют эту защиту *)

   (* если старое разрешенное количество токенов для расходования больше нуля, его можно изменить только на ноль.
   Если оно равно нулю, его можно изменить на другое натуральное число *)
   if spenderAllowance > 0n and value > 0n then
     failwith("UnsafeAllowanceChange")
   else skip;

   (* вносим в данные аккаунта новое разрешенное количество токенов для расходывания *)
   senderAccount.allowances[spender] := value;

   (* обновляем хранилище смарт-контракта *)
   s.ledger[Tezos.sender] := senderAccount;

 } with (noOperations, s)

(* Функции getBalance, getAllowance и getTotalSupply относятся к обзорным (view).
Они возвращают запрашиваемое значение не пользователю, а специальному промежуточному контракту (proxy-contract).
Во входящих параметрах для вызова этих функций пользователь должен указать адрес промежуточного контракта *)

(* Функция getBallance возвращает значение баланса заданного адреса *)
function getBalance (const owner : address; const contr : contract(amt); var s : storage) : return is
 block {
     //присваиваем константе ownerAccaunt данные аккаунта
   const ownerAccount : account = getAccount(owner, s);
 }
 //возвращаем промежуточному контракту баланс аккаунта
 with (list [transaction(ownerAccount.balance, 0tz, contr)], s)

(* Функция getAllowance возвращает количество разрешенных для расходования токенов запрашиваемого аккаунта *)
function getAllowance (const owner : address; const spender : address; const contr : contract(amt); var s : storage) : return is
 block {
     //получаем данные аккаунта, а из них — количество разрешенных для расходования токенов
   const ownerAccount : account = getAccount(owner, s);
   const spenderAllowance : amt = getAllowance(ownerAccount, spender, s);
 } with (list [transaction(spenderAllowance, 0tz, contr)], s)

(* Функция getTotalSupply возвращает количество токенов на балансах всех пользователей *)
function getTotalSupply (const contr : contract(amt); var s : storage) : return is
 block {
   skip
 } with (list [transaction(s.totalSupply, 0tz, contr)], s)

(* Главная функция принимает название псевдо-точки входа и ее параметры *)
function main (const action : entryAction; var s : storage) : return is
 block {
   skip
 } with case action of
   | Transfer(params) -> transfer(params.0, params.1.0, params.1.1, s)
   | Approve(params) -> approve(params.0, params.1, s)
   | GetBalance(params) -> getBalance(params.0, params.1, s)
   | GetAllowance(params) -> getAllowance(params.0.0, params.0.1, params.1, s)
   | GetTotalSupply(params) -> getTotalSupply(params.1, s)
 end;