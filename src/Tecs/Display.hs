module Tecs.Display where

import qualified UI.HSCurses.CursesHelper as CH
import qualified UI.HSCurses.Curses as C
import Prelude
import Control.Monad.Writer
import Data.Char (ord)
import System.Locale.SetLocale
import qualified Data.ByteString as B
import qualified Data.ByteString.UTF8 as U

import Tecs.Types


withCurses :: IO () -> IO ()
withCurses f = do
  setLocale LC_ALL Nothing
  CH.start
  C.echo False
  C.keypad C.stdScr True
  C.nl True
  f
  C.endWin
  CH.end

clearScreen = C.wclear C.stdScr

getScreenSize :: IO (Int, Int)
getScreenSize = C.scrSize

clamp :: Int -> Int -> Int -> Int
clamp low high = max low . min high

refresh = C.refresh

nextKey = CH.getKey C.refresh

charAsUtf8 c = maybe '?' fst (U.uncons $ U.fromString $ c:"")

cursesKeyToEvt :: C.Key -> Event
cursesKeyToEvt (C.KeyChar '\ESC') = KeyEvent KeyEscape
cursesKeyToEvt (C.KeyChar '\n')   = KeyEvent KeyEnter
cursesKeyToEvt (C.KeyChar '\DEL') = KeyEvent KeyDel
cursesKeyToEvt (C.KeyChar c)      = KeyEvent $ KeyChar c
cursesKeyToEvt C.KeyUp            = KeyEvent KeyUp
cursesKeyToEvt C.KeyDown          = KeyEvent KeyDown
cursesKeyToEvt C.KeyLeft          = KeyEvent KeyLeft
cursesKeyToEvt C.KeyRight         = KeyEvent KeyRight
cursesKeyToEvt C.KeyEnter         = KeyEvent KeyEnter
cursesKeyToEvt _                  = NoEvent


waitEvent :: IO (Event)
waitEvent = waitEvent' (U.fromString "")

waitEvent' :: B.ByteString -> IO (Event)
waitEvent' bs = do
  key <- nextKey
  case key of
    C.KeyChar c ->
      let nextBs = B.concat [bs, (U.fromString $ c:"")]
      in case U.uncons nextBs of
        Just (realChar, _) -> return $ cursesKeyToEvt $ C.KeyChar realChar
        otherwise -> waitEvent' nextBs
    otherwise ->
      return $ cursesKeyToEvt key

printStr :: Pos -> String -> RenderW ()
printStr p s = RenderW ((), [PrintStr p s])
setCursor :: Pos -> RenderW ()
setCursor p = RenderW ((), [SetCursor p])

drawToScreen :: Box -> RenderAction -> IO ()
drawToScreen (Box top left height width) command =
  case command of
    SetCursor (Pos line row) -> C.move (top + (clamp 0 height line))
                                       (left + (clamp 0 width row))
    PrintStr (Pos line row) str -> do
      let realLine = line + top
          realRow  = row + left
      mapM (\(r, c) -> C.mvAddCh realLine r $ (fromIntegral . ord) c)
           (zip [realRow..] str)
      return ()
