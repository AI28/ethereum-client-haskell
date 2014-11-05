{-# LANGUAGE OverloadedStrings #-}

module AddressState (
  AddressState(..),
  getAddressState,
  getAllAddressStates,
  putAddressState
  ) where

import Control.Monad.Trans.Resource
import qualified Data.ByteString as B
import Data.Functor
import Numeric

import Address
import Colors
import DBs
import EthDB
import Format
import qualified NibbleString as N
import RLP
import SHA
import Util

data AddressState = AddressState { addressStateNonce::Integer, balance::Integer, contractRoot::Integer, codeHash::SHA } deriving (Show)

instance Format AddressState where
  format a = blue "AddressState" ++
             tab("\nnonce: " ++ showHex (addressStateNonce a) "" ++
                 "\nbalance: " ++ show (toInteger $ balance a) ++
                 "\ncontractRoot: " ++ showHex (contractRoot a) "" ++
                 "\ncodeHash: " ++ format (codeHash a))
  
instance RLPSerializable AddressState where
  rlpEncode a = RLPArray [rlpEncode $ toInteger $ addressStateNonce a, rlpEncode $ toInteger $ balance a, rlpEncode $ toInteger $ contractRoot a, rlpEncode $ codeHash a]

  rlpDecode (RLPArray [n, b, cr, ch]) =
    AddressState {
      addressStateNonce=fromInteger $ rlpDecode n,
      balance=fromInteger $ rlpDecode b,
      contractRoot=fromInteger $ rlpDecode cr,
      codeHash=rlpDecode ch
      } 
  rlpDecode x = error $ "Missing case in rlpDecode for AddressState: " ++ format x

addressAsNibbleString::Address->N.NibbleString
addressAsNibbleString (Address s) = N.EvenNibbleString $ B.pack $ integer2Bytes $ fromIntegral s

getAddressState::DB->SHAPtr->Address->ResourceT IO (Maybe AddressState)
getAddressState db p address = do
  states <- getKeyVals db p $ addressAsNibbleString address
  case states of
    [] -> return Nothing
    [state] -> return $ Just $ rlpDecode $ rlpDeserialize $ snd state
    _ -> error ("getAddressStates found multiple states for: " ++ format address)
  

getAllAddressStates::DB->SHAPtr->ResourceT IO [(N.NibbleString, AddressState)]
getAllAddressStates db p = do
  states <- getKeyVals db p ""
  return $ fmap (rlpDecode . rlpDeserialize) <$> states

  

putAddressState::DB->SHAPtr->Address->AddressState->ResourceT IO SHAPtr
putAddressState db p address newState = do
  putKeyVal db p (addressAsNibbleString address) (rlpSerialize $ rlpEncode newState)

