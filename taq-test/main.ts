import { App } from './app'
//импортируем Tx.ts
import { Tx } from './tx'
//меняем RPC-ссылку из мейннета на тестовую сеть. Не пугайтесь smartpy в ссылке — это просто адрес сервера
const RPC_URL = 'https://rpc.granada.tzstats.com' 
const ADDRESS = 'tz1aRoaRhSpRYvFdyvgWLL6TGyRoGF51wDjM'
//вызываем функцию Tx, передаем ей ссылку на тестовую сеть и просим активировать аккаунт
new Tx(RPC_URL).activateAccount()