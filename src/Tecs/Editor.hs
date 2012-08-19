{-# LANGUAGE NoImplicitPrelude #-}

module Tecs.Editor where

import Prelude as P

import Tecs.Types as TT
import Tecs.Text
import Tecs.Buffer
import Tecs.Display

data SimpleEditor = SimpleEditor {
  buffer :: Buffer,
  cursorPos :: Pos,
  fileName :: String
  }


newtype State s a = State {
  runState :: s -> (a, s)
  }
instance Monad (State s) where
  return x = State $ \s -> (x, s)
  m >>= k  = State $ \s -> let (a, s') = (runState m) s
                           in runState (k a) s'

execState :: State s a -> s -> s
execState m s = snd (runState m s)

gets :: State s s
gets = State $ \s -> (s, s)

get :: (s -> b) -> State s b
get f = gets >>= (\st -> return (f st))

puts :: s -> State s ()
puts s = State $ \_ -> ((), s)

mods :: (s -> s) -> State s ()
mods f = gets >>= (\s -> puts $ f s)

instance Editor SimpleEditor where
  render editor height width = do
    renderBuffer Crop (buffer editor) height width
    setCursor (cursorPos editor)
  respond editor evt = execState ((lookupWithDefault evtMap evt) evt) editor

type SimpleEditorAction = State SimpleEditor ()

advance pos = pos { row = (row pos) + 1}

insertChar :: Char -> SimpleEditorAction
insertChar c = do
  st <- gets
  let cursor = cursorPos st
      buf = buffer st
  puts st { buffer = insertCharIntoBuffer buf cursor c,
            cursorPos = advance cursor }

insertLinebreak :: Event -> SimpleEditorAction
insertLinebreak _ = do
  st <- gets
  let cursor = cursorPos st
      buf = buffer st
  puts st { buffer = insertLinebreakIntoBuffer buf cursor,
            cursorPos = Pos { line = (line cursor) + 1,
                              row = 0 } }

cursorDown _ = mods $ \ed ->
  let cp = cursorPos ed
      nextLinePos = min (numLines $ buffer ed) (line cp + 1)
  in ed { cursorPos = cp { line = nextLinePos }}

cursorUp _ = mods $ \ed ->
  let cp = cursorPos ed
      nextLinePos = max 0 (line cp - 1)
  in ed { cursorPos = cp { line = nextLinePos }}

handleOther evt = case evt of
  KeyEvent (KeyChar c) -> insertChar c
  otherwise -> return ()

evtMap = defaultMapFromList [
  (KeyEvent KeyUp, cursorUp),
  (KeyEvent KeyDown, cursorDown),
  (KeyEvent KeyEnter, insertLinebreak)
  ] handleOther


simpleEditorFromFile :: String -> IO (SimpleEditor)
simpleEditorFromFile filename = do
  s <- readFile filename
  return $ SimpleEditor (strToBuffer s) (Pos 0 0) filename

renderEditor :: Editor a => Box -> a -> IO ()
renderEditor b@(Box _ _ height width) editor =
  let (_, commands) = execRender (render editor height width)
  in do mapM (drawToScreen b) commands
        return ()

data InfoLineEditor = InfoLineEditor {
  infoBuffer :: Buffer
  }
instance Editor InfoLineEditor where
  render editor height width =
    renderBuffer Crop (infoBuffer editor) height width
  respond editor evt = editor

setInfoLineContent infoLineEditor str =
  infoLineEditor { infoBuffer = strToBuffer str }

defaultInfoLineEditor = InfoLineEditor $ strToBuffer ""
