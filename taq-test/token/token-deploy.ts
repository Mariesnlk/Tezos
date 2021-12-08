import { TezosToolkit } from '@taquito/taquito'
import { importKey } from '@taquito/signer'

const { Tezos } = require('@taquito/taquito')
const fs = require('fs')

const provider = 'https://hangzhounet.api.tez.ie/'

async function deploy() {
  const tezos = new TezosToolkit(provider)
  await importKey(
    tezos,
    "jaxirwcg.sgygwisx@tezos.example.org", //почта
   "FmeuDtv04O", //пароль
   [
    "index",
    "foot",
    "lumber",
    "poem",
    "rib",
    "limb",
    "seed",
    "object",
    "scorpion",
    "mutual",
    "observe",
    "quality",
    "match",
    "output",
    "twist"
   ].join(' '),
   "f6da8540e818ecbeefa5c7b94d67ef0346e42229"//приватный ключ
 );

  try {
    const op = await tezos.contract.originate({
      // считываем код из файла token.json
      code: JSON.parse(fs.readFileSync('./token.json').toString()),
      // задаем состояние хранилища на языке Michelson. Замените оба адреса на адрес своего аккаунта в тестовой сети,
      // а числа — на количество токенов, которое вы хотите выпустить
      init: '(Pair { Elt "tz1d3ABoo5xvCEc8FiNCJfngGM9H6Tm6Reov" (Pair { Elt "tz1d3ABoo5xvCEc8FiNCJfngGM9H6Tm6Reov" 1000 } 1000) } 1000)',
    })

    //начало развертывания
    console.log('Awaiting confirmation...')
    const contract = await op.contract()
    //отчет о развертывании: количество использованного газа, значение хранилища
    console.log('Gas Used', op.consumedGas)
    console.log('Storage', await contract.storage())
    //хеш операции, по которому можно найти контракт в блокчейн-обозревателе
    console.log('Operation hash:', op.hash)
  } catch (ex) {
    console.error(ex)
  }
}

deploy()