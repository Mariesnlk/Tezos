import { TezosToolkit } from '@taquito/taquito';
import { importKey } from '@taquito/signer';

const provider = 'https://rpc.granada.tzstats.com';

async function deploy() {
 const tezos = new TezosToolkit(provider);
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
      //код смарт-контракта
      code: `{ parameter int ;
       storage int ;
       code { UNPAIR ; ADD ; NIL operation ; PAIR } }
           `,
      //значение хранилища
      init: `0`,
    });

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