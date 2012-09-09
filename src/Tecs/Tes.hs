{-# LANGUAGE QuasiQuotes #-}

module Main where

import qualified Control.Monad.State as S
import qualified Data.Map as Map
import System.Environment (getArgs)

import Tecs.Types
import Tecs.Display
import Tecs.Editor
import Tecs.Buffer

import Debug.Trace (trace)

forwardEvtToEditor globalState evt =
  globalState { editor = respond (editor globalState) evt }

topEvtMap :: DefaultMap Event (GlobalState -> Event -> IO GlobalState)
topEvtMap =
  let m = Map.fromList [
        (KeyEvent $ KeyCtrlChar 'Q', \st _ -> return $ st { shouldQuit = True }),
        (KeyEvent $ KeyCtrlChar 'S', \st _ -> do
            let ed = editor st
            writeFile (fileName ed) (bufferToStr $ buffer ed)
            return st { editor = ed { lastSavePtr = 0 } }
            )
        ]
  in DefaultMap m (\ts ev -> do let ts' = forwardEvtToEditor ts ev
                                return ts'
                  )

handleEvt :: GlobalState -> Event -> IO GlobalState
handleEvt globalState evt = (lookupWithDefault topEvtMap evt) globalState evt

usage :: String
usage = unlines [
  "USAGE",
  "  tes <file>"
  ]

infoLineContentFor globalState =
  let ed = editor globalState
      modStr = if isModified ed
               then "*"
               else " "
      fn     = fileName ed
  in "  " ++ modStr ++ "  " ++ fn

renderAndWaitEvent :: GlobalState -> IO Event
renderAndWaitEvent st = do
  (y, x) <- getScreenSize
  renderEditor (Box (y - 1) 0       1 x) (infoLine st)
  renderEditor (Box 0       0 (y - 1) x) (editor st)
  refresh
  waitEvent

mainLoop globalState = do
  (y, x) <- getScreenSize
  let infoL     = infoLine globalState
      globalState' = globalState { editor = (editor globalState) { viewHeight = y - 1 },
                             infoLine = setInfoLineContent infoL (infoLineContentFor globalState) }
  evt <- renderAndWaitEvent globalState'
  nextGlobalState <- handleEvt globalState' evt
  if (shouldQuit nextGlobalState)
    then return ()
    else mainLoop nextGlobalState

main = do
  args <- getArgs
  startEditor args

startEditor args = do
  if null args
    then putStrLn usage
    else do editor <- simpleEditorFromFile (args !! 0)
            withCurses $ mainLoop (defaultGlobalState { editor = editor })
  return ()

