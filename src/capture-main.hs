module Main where

import Control.Monad
import Control.Concurrent
import System.Directory
import System.FilePath
import Graphics.X11.XScreenSaver (compiledWithXScreenSaver)
import System.IO
import System.Posix.IO
import System.IO.Error
import System.Exit
import System.Locale.SetLocale
import System.Console.GetOpt
import System.Environment
import Data.Maybe
import Data.Version (showVersion)

import Capture
import TimeLog

import Paths_arbtt (version)


data Conf = Conf {
	cSampleRate :: Integer
	}
defaultConf = Conf 60

data Opts = Help | Version | SetRate Integer
	deriving Eq

versionStr = "arbtt-capture " ++ showVersion version
header = "Usage: arbtt-capture [OPTIONS...]"

options :: [OptDescr Opts]
options = 
     [ Option "h?"     ["help"]
              (NoArg Help)
	      "show this help"
     , Option ['V']    ["version"]
              (NoArg Version)
	      "show the version number"
     , Option ['r']    ["sample-rate"]
     	      (ReqArg (SetRate . read) "RATE")
	      "set the sample rate in seconds (default: 60)"
     ]	     

-- | This is very raw, someone ought to improve this
lockFile filename = flip catch (\e -> hPutStrLn stderr ("arbtt [Error]: Could not aquire lock for " ++ filename ++"!") >> exitFailure) $ do
    fd <- openFd (filename  ++ ".lck") WriteOnly (Just 0644) defaultFileFlags
    setLock fd (WriteLock, AbsoluteSeek, 0, 0)

main = do
    setLocale LC_ALL (Just "") 
    unless compiledWithXScreenSaver $
    	hPutStrLn stderr "arbtt [Warning]: X11 was compiled without support for XScreenSaver"
    
    args <- getArgs
    flags <- case getOpt Permute options args of
    	(o, [], []) | Help `notElem` o && Version `notElem` o -> return o
	(o, _, _)   | Version `elem` o -> do
		hPutStrLn stderr versionStr
		exitSuccess
	(o, _, _)   | Help `elem` o -> do
                hPutStr stderr (usageInfo header options)
		exitSuccess
	(_,_,errs) -> do
                hPutStr stderr (concat errs ++ usageInfo header options)
                exitFailure

    let sampleRate = foldr (.) id
                     (map (\f -> case f of {SetRate r -> const r; _ -> id}) flags)
		     60

    dir <- getAppUserDataDirectory "arbtt"
    createDirectoryIfMissing False dir
    let captureFile = dir </> "capture.log"
    lockFile captureFile
    runLogger captureFile (sampleRate * 1000) captureData