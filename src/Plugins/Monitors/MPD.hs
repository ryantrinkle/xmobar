-----------------------------------------------------------------------------
-- |
-- Module      :  Plugins.Monitors.MPD
-- Copyright   :  (c) Jose A Ortega Ruiz
-- License     :  BSD-style (see LICENSE)
--
-- Maintainer  :  Jose A Ortega Ruiz <jao@gnu.org>
-- Stability   :  unstable
-- Portability :  unportable
--
--  MPD status and song
--
-----------------------------------------------------------------------------

module Plugins.Monitors.MPD ( mpdConfig, runMPD, mpdWait, mpdReady ) where

import Data.List
import Data.Maybe
import Plugins.Monitors.Common
import System.Console.GetOpt
import qualified Network.MPD as M
import Control.Concurrent (threadDelay)

mpdConfig :: IO MConfig
mpdConfig = mkMConfig "MPD: <state>"
              [ "bar", "state", "statei", "volume", "length"
              , "lapsed", "remaining", "plength", "ppos", "file"
              , "name", "artist", "composer", "performer"
              , "album", "title", "track", "genre"
              ]

data MOpts = MOpts
  { mPlaying :: String
  , mStopped :: String
  , mPaused :: String
  }

defaultOpts :: MOpts
defaultOpts = MOpts
  { mPlaying = ">>"
  , mStopped = "><"
  , mPaused = "||"
  }

options :: [OptDescr (MOpts -> MOpts)]
options =
  [ Option "P" ["playing"] (ReqArg (\x o -> o { mPlaying = x }) "") ""
  , Option "S" ["stopped"] (ReqArg (\x o -> o { mStopped = x }) "") ""
  , Option "Z" ["paused"] (ReqArg (\x o -> o { mPaused = x }) "") ""
  ]

runMPD :: [String] -> Monitor String
runMPD args = do
  opts <- io $ mopts args
  status <- io $ M.withMPD M.status
  song <- io $ M.withMPD M.currentSong
  s <- parseMPD status song opts
  parseTemplate s

mpdWait :: IO ()
mpdWait = do
  status <- M.withMPD $ M.idle [M.PlayerS, M.MixerS]
  case status of
    Left _ -> threadDelay 10000000
    _ -> return ()

mpdReady :: [String] -> Monitor Bool
mpdReady _ = do
  response <- io $ M.withMPD M.ping
  case response of
    Right _         -> return True
    -- Only cases where MPD isn't responding is an issue; bogus information at
    -- least won't hold xmobar up.
    Left M.NoMPD    -> return False
--    Left M.TimedOut -> return False
    Left _          -> return True

mopts :: [String] -> IO MOpts
mopts argv =
  case getOpt Permute options argv of
    (o, _, []) -> return $ foldr id defaultOpts o
    (_, _, errs) -> ioError . userError $ concat errs

parseMPD :: M.Response M.Status -> M.Response (Maybe M.Song) -> MOpts
            -> Monitor [String]
parseMPD (Left e) _ _ = return $ show e:replicate 18 ""
parseMPD (Right st) song opts = do
  songData <- parseSong song
  bar <- showPercentBar (100 * b) b
  return $ [bar, ss, si, vol, len, lap, remain, plen, ppos] ++ songData
  where s = M.stState st
        ss = show s
        si = stateGlyph s opts
        vol = maybe "0" int2str $ M.stVolume st
        (p, t) = fromMaybe (0, 0) $ M.stTime st
        [lap, len, remain] = map showTime [floor p, t, max 0 (t - floor p)]
        b = if t > 0 then realToFrac $ p / fromIntegral t else 0
        plen = int2str $ M.stPlaylistLength st
        ppos = maybe "" (int2str . (+1)) $ M.stSongPos st

stateGlyph :: M.State -> MOpts -> String
stateGlyph s o =
  case s of
    M.Playing -> mPlaying o
    M.Paused -> mPaused o
    M.Stopped -> mStopped o

parseSong :: M.Response (Maybe M.Song) -> Monitor [String]
parseSong (Left _) = return $ repeat ""
parseSong (Right Nothing) = return $ repeat ""
parseSong (Right (Just s)) =
  let str sel = maybe "" (intercalate ", " . map M.toString) (M.sgGetTag sel s)
      sels = [ M.Name, M.Artist, M.Composer, M.Performer
             , M.Album, M.Title, M.Track, M.Genre ]
      fields = M.toString (M.sgFilePath s) : map str sels
  in mapM showWithPadding fields

showTime :: Integer -> String
showTime t = int2str minutes ++ ":" ++ int2str seconds
  where minutes = t `div` 60
        seconds = t `mod` 60

int2str :: (Show a, Num a, Ord a) => a -> String
int2str x = if x < 10 then '0':sx else sx where sx = show x
