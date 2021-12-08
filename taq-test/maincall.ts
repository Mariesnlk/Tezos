import { Call } from './call'

const RPC_URL = 'https://rpc.granada.tzstats.com'
const CONTRACT = 'KT1A32SPPN2t1cnXFVLsu4NLfPHWhdjXPuFj' //адрес опубликованного контракта
const ADD = 5 //число, которое получит главная функция. Можете изменить его на другое
new Call(RPC_URL).add(ADD, CONTRACT)