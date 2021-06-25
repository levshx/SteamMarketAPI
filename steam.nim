#
#            Nim's Runtime Library
#        (c) Copyright 2021 Pavel Levshic
#

## This library allows you to use the open Web API Steam.
## 
##
## Overview
## ========
##
## Create Steam client
## ------------
##
## Use only `var`
##
## .. code-block:: Nim
##   import steam
##
##   # input you Key Steam Web API
##   let keySteam = "XXXXYYYYZZZZDDDDAAAA1234"
##
##   # Create Steam session
##   var clientSteam = newSteamClient(keySteam) 
##
## Test 
## --------------
##
## Test text
##

import json, httpclient, strutils

# Decode specific chars to % in URL
proc escapeLink(s: string): string =
  result = newStringOfCap(s.len + s.len shr 2)
  for c in items(s):
    case c
    of 'a'..'z', '_', 'A'..'Z', '0'..'9', '.', '#', ',', '/':
      result.add c
    else:
      add(result, "%")
      add(result, toHex(ord(c), 2))


type
  SteamClient = object  ## Client Steam
    steamWebAPIKey*: string


proc newSteamClient*(keyWebAPI: string): SteamClient =
  ## Create Steam client
  result.steamWebAPIKey = keyWebAPI



type
  ServerInfo* = object ## Structure Steam server information
    servertime*: int
    servertimestring*: string

proc getServerInfo*(client: SteamClient): ServerInfo =
  let url = "https://api.steampowered.com/ISteamwebAPIUtil/GetServerInfo/v1/"
  let jsonObject = parseJson(newHttpClient().getContent(url))
  return to(jsonObject, ServerInfo)



type
  MinItem* = object ## Это класс минимальной информации стоимости предмета на торговой площадке Steam
    success*: bool
    lowest_price*: string
    volume*: string
    median_price*: string


proc getMinItem*(client: SteamClient, appid: int, vallet: int,
    market_hash_name: string): MinItem =
  ## Процедура получения минимальной информации стоимости предмета
  ## на торговой площадке Steam
  let url = "https://steamcommunity.com/market/priceoverview/?appid="&intToStr(
      appid)&"&currency="&intToStr(vallet)&"&market_hash_name="&escapeLink(market_hash_name)
  let jsonObject = parseJson(newHttpClient().getContent(url))
  return to(jsonObject, MinItem)


#
# Trade Market Service (IEconService)
# Method (GetTradeHistory)
# https://api.steampowered.com/IEconService/GetTradeHistory/v1/
#
type
  TradeAsset* = object
    appid*: int
    contextid*: string
    assetid*: string
    amount*: string
    classid*: string
    instanceid*: string
    new_assetid*: string
    new_contextid*: string

  Trade* = object
    tradeid*: string
    steamid_other*: string
    time_init*: int
    status*: int
    assets_received*: seq[TradeAsset]
    assets_given*: seq[TradeAsset]



proc tradeHistory*(client: SteamClient, max_trades: int): seq[Trade] =
  let url = "https://api.steampowered.com/IEconService/GetTradeHistory/v1/?key="&(
      client.steamWebAPIKey)&"&max_trades="&($max_trades)
  let jsonObject = parseJson(newHttpClient().getContent(url))
  let jsonResponse = jsonObject["response"]
  let jsonTrades = jsonResponse["trades"]
  doAssert jsonTrades.kind == JArray
  for jsonTrade in jsonTrades:
    if not jsonTrade.hasKey("assets_received"):
      jsonTrade.add("assets_received", parseJson("[]"))
    if not jsonTrade.hasKey("assets_given"):
      jsonTrade.add("assets_given", parseJson("[]"))
    result.add(to(jsonTrade, Trade))
  return result

#
# Get Icon URL
# http://cdn.steamcommunity.com/economy/image/ +IMAGE CODE
#

proc getAssetMarketIconURL*(client: SteamClient, icon_code: string): string =
  let url = "http://cdn.steamcommunity.com/economy/image/"&icon_code
  return url


#
# Inventory (NO API)
# CARD
# https://steamcommunity.com/inventory/76561198082780051/730/2
#
type
  InventoryAsset* = object
    appid*: int
    classid*: string
    instanceid*: string
    currency*: int
    icon_url*: string
    tradable*: int
    name*: string
    name_color*: string
    market_name*: string
    market_hash_name*: string
    commodity*: int
    market_tradable_restriction*: int
    marketable*: int

proc getProfileInventory*(client: SteamClient, steamID64: int64, gameID: int,
    valueWTF: int): seq[InventoryAsset] =
  let url = "https://steamcommunity.com/inventory/"&($steamID64)&"/"&(
      $gameID)&"/"&($valueWTF)
  let jsonObject = parseJson(newHttpClient().getContent(url))
  let jsonDescriptions = jsonObject["descriptions"] # More Information
  doAssert jsonDescriptions.kind == JArray
  for jsonAsset in jsonDescriptions:
    result.add(to(jsonAsset, InventoryAsset))
  return result


#
# Steam Economy Service (ISteamEconomy)
# Method (GetAssetClassInfo) v0001
# https://api.steampowered.com/ISteamEconomy/GetAssetClassInfo/v0001/?key=XXX&appid=730&class_count=1&classid0=3106076656
#
type
  AssetClassInfo* = object
    classid*: string
    icon_url*: string
    tradable*: string
    name*: string
    name_color*: string
    market_name*: string
    market_hash_name*: string
    commodity*: string
    market_tradable_restriction*: string
    marketable*: string

proc getAssetClassInfo*(client: SteamClient, gameID: int,
    classid: int64): AssetClassInfo =
  let url = "https://api.steampowered.com/ISteamEconomy/GetAssetClassInfo/v0001/?key="&(
      client.steamWebAPIKey)&"&appid="&($gameID)&"&class_count=1&classid0="&($classid)
  let jsonObject = parseJson(newHttpClient().getContent(url))
  let jsonResult = jsonObject["result"] # More Information
  let jsonAsset = jsonResult[$classid]
  return to(jsonAsset, AssetClassInfo)


#
# IPlayerService
# Method (GetOwnedGames) v0001
#http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=kkk&steamid=76561198082780098
#
type
  OwnedGames* = object
    game_count*: int
    games*: seq[Game]

  Game* = object
    appid*: int
    playtime_forever*: int
    playtime_windows_forever*: int
    playtime_mac_forever*: int
    playtime_linux_forever*: int

proc getOwnedGames*(client: SteamClient, steamID64: int64): OwnedGames =
  let url = "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key="&(
      client.steamWebAPIKey)&"&steamid="&($steamID64)
  let jsonObject = parseJson(newHttpClient().getContent(url))
  let jsonResponse = jsonObject["response"]
  result.game_count = to(jsonResponse["game_count"], int)
  if (result.game_count > 0):
    let jsonGames = jsonResponse["games"]
    for jsonGame in jsonGames:
      result.games.add(to(jsonGame, Game))
  return result

#
# ISteamEconomy (GAME PRICES)
# Method (GetAssetPrices) v0001
# https://api.steampowered.com/ISteamEconomy/GetAssetPrices/v1/?key=sss&appid=730
#
type
  GameAssetPrice* = object
    name*: string
    date*: string
    classid*: string
    prices*: Prices

  Prices* = object
    USD*: int
    GBP*: int
    EUR*: int
    RUB*: int
    BRL*: int
    JPY*: int
    NOK*: int
    IDR*: int
    MYR*: int
    PHP*: int
    SGD*: int
    THB*: int
    VND*: int
    KRW*: int
    TRY*: int
    UAH*: int
    MXN*: int
    CAD*: int
    AUD*: int
    NZD*: int
    PLN*: int
    CHF*: int
    AED*: int
    CLP*: int
    CNY*: int
    COP*: int
    PEN*: int
    SAR*: int
    TWD*: int
    HKD*: int
    ZAR*: int
    INR*: int
    ARS*: int
    CRC*: int
    ILS*: int
    KWD*: int
    QAR*: int
    UYU*: int
    KZT*: int

proc getGameAssetPrices*(client: SteamClient, gameID: int): seq[
    GameAssetPrice] =
  let url = "https://api.steampowered.com/ISteamEconomy/GetAssetPrices/v1/?key="&(client.steamWebAPIKey)&"&appid="&($gameID)
  let jsonObject = parseJson(newHttpClient().getContent(url))
  let jsonResult = jsonObject["result"] # More Information
  let jsonAssets = jsonResult["assets"]
  return to(jsonAssets, seq[GameAssetPrice])
