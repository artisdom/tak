module Tecs.Editor.Cursor where

import Tecs.Types
import Tecs.Buffer


insertPos :: SimpleEditor -> Pos
insertPos se = let cPos = cursorPos se
                   l = min (line cPos) (lastLineIdx (buffer se))
                   r = min (row cPos) (length $ lineAt l $ buffer se)
               in Pos l r

screenPos :: SimpleEditor -> Pos
screenPos se = let iPos = insertPos se
                   screenLine = (line iPos) - (lineScroll se)
                   isOnScreen = screenLine >= 0
               in if isOnScreen
                  then iPos { line = screenLine }
                  else Pos 0 0

fixScroll ed =
  let cp = cursorPos ed
      l  = line cp
      ls = lineScroll ed
      h  = viewHeight ed
      isBefore = l  < ls
      isAfter  = l >= ls + h
      newLineScroll
        | isBefore  = l
        | isAfter   = l - h + 1
        | otherwise = ls
  in ed { lineScroll = newLineScroll }

cursorDown ed =
  let cp = cursorPos ed
      nextLinePos = min (lastLineIdx $ buffer ed) (line cp + 1)
  in fixScroll $ ed { cursorPos = cp { line = nextLinePos }}

cursorUp ed =
  let cp = cursorPos ed
      nextLinePos = max 0 (line cp - 1)
  in fixScroll $ ed { cursorPos = cp { line = nextLinePos }}

cursorLeft ed =
  let cp = insertPos ed
      l = line cp
      r = row cp
      lenOfLineBefore = length $ lineAt (l - 1) $ buffer ed
  in if r > 0
     then ed { cursorPos = cp { row = r - 1 }}
     else if l > 0
          then fixScroll $ ed { cursorPos = Pos (l - 1) lenOfLineBefore }
          else ed

cursorRight ed =
  let cp = insertPos ed
      l = line cp
      r = row cp
      lenCurLine = length $ lineAt l $ buffer ed
  in if r < lenCurLine
     then ed { cursorPos = cp { row = r + 1 } }
     else if l < (lastLineIdx $ buffer ed)
          then fixScroll $ ed { cursorPos = Pos (l + 1) 0 }
          else ed

cursorEndOfLine ed =
  let cp = cursorPos ed
      nextRowPos = (length $ lineAt (line cp) (buffer ed))
  in ed { cursorPos = cp { row = nextRowPos }}

cursorBeginningOfLine ed = ed { cursorPos = (cursorPos ed) { row = 0 } }

cursorPageDown ed =
  let cp = cursorPos ed
      l = line cp
      pageLen = (viewHeight ed) - 3
      lastBufLineIdx = lastLineIdx $ buffer ed
  in fixScroll $ ed { cursorPos = cp { line = min (l + pageLen) lastBufLineIdx } }

cursorPageUp ed =
  let cp = cursorPos ed
      l = line cp
      pageLen = (viewHeight ed) - 3
  in fixScroll $ ed { cursorPos = cp { line = max 0 (l - pageLen) } }
