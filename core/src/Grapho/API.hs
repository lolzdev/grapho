{-# LANGUAGE ForeignFunctionInterface #-}

module Grapho.API where

import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Foreign.C.String (CString, newCString)
import Foreign.C.Types (CInt (..))
import Foreign.Marshal.Alloc (free)
import System.IO.Unsafe (unsafePerformIO)

counter :: IORef CInt
counter = unsafePerformIO (newIORef 0)
{-# NOINLINE counter #-}

grapho_add :: CInt -> CInt -> IO CInt
grapho_add a b = pure (a + b)

grapho_tick :: IO CInt
grapho_tick =
  atomicModifyIORef' counter $ \value ->
    let next = value + 1
     in (next, next)

grapho_hello :: IO CString
grapho_hello = newCString "Hello from Haskell"

grapho_free_string :: CString -> IO ()
grapho_free_string = free

foreign export ccall grapho_add :: CInt -> CInt -> IO CInt
foreign export ccall grapho_tick :: IO CInt
foreign export ccall grapho_hello :: IO CString
foreign export ccall grapho_free_string :: CString -> IO ()
