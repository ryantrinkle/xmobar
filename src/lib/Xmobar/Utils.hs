{-# LANGUAGE CPP #-}

------------------------------------------------------------------------------
-- |
-- Module: Utils
-- Copyright: (c) 2010, 2018 Jose Antonio Ortega Ruiz
-- License: BSD3-style (see LICENSE)
--
-- Maintainer: Jose A Ortega Ruiz <jao@gnu.org>
-- Stability: unstable
-- Portability: unportable
-- Created: Sat Dec 11, 2010 20:55
--
--
-- Miscellaneous utility functions
--
------------------------------------------------------------------------------


module Xmobar.Utils
  (expandHome, changeLoop, hGetLineSafe, nextEvent', tenthSeconds)
where

import Control.Monad
import Control.Concurrent
import Control.Concurrent.STM
import System.Posix.Types (Fd(..))

import System.Environment
import System.FilePath
import System.IO

import Graphics.X11.Xlib (
  Display(..), XEventPtr, nextEvent, pending, connectionNumber)

#if defined XFT || defined UTF8
import qualified System.IO as S (hGetLine)
#endif

hGetLineSafe :: Handle -> IO String
#if defined XFT || defined UTF8
hGetLineSafe = S.hGetLine
#else
hGetLineSafe = hGetLine
#endif


expandHome :: FilePath -> IO FilePath
expandHome ('~':'/':path) = fmap (</> path) (getEnv "HOME")
expandHome p = return p

changeLoop :: Eq a => STM a -> (a -> IO ()) -> IO ()
changeLoop s f = atomically s >>= go
 where
    go old = do
        f old
        go =<< atomically (do
            new <- s
            guard (new /= old)
            return new)

-- | A version of nextEvent that does not block in foreign calls.
nextEvent' :: Display -> XEventPtr -> IO ()
nextEvent' d p = do
    pend <- pending d
    if pend /= 0
        then nextEvent d p
        else do
            threadWaitRead (Fd fd)
            nextEvent' d p
 where
    fd = connectionNumber d


-- | Work around to the Int max bound: since threadDelay takes an Int, it
-- is not possible to set a thread delay grater than about 45 minutes.
-- With a little recursion we solve the problem.
tenthSeconds :: Int -> IO ()
tenthSeconds s | s >= x = do threadDelay (x * 100000)
                             tenthSeconds (s - x)
               | otherwise = threadDelay (s * 100000)
               where x = (maxBound :: Int) `div` 100000
