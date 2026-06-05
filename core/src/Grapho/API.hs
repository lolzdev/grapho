{-# LANGUAGE ForeignFunctionInterface #-}

module Grapho.API where

import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Foreign.C.String (CString, newCString)
import Foreign.C.Types (CInt (..))
import Foreign.Marshal.Alloc (free)
import System.IO.Unsafe (unsafePerformIO)
