module Tak.Editor.Selection where

import Tak.Types
import Tak.Buffer
import Tak.Range
import Tak.Editor.Cursor
import Tak.Editor.Undo (pushUndo)
import Data.List (sort)
import qualified Data.Sequence as Seq

import Control.Lens


startSelecting :: SimpleEditor -> SimpleEditor
startSelecting st =
  st { selState = (selState st) { openRange = Just (insertPos st) } }

cancelSelecting :: SimpleEditor -> SimpleEditor
cancelSelecting st =
  st { selState = (selState st) { openRange = Nothing } }


finishSelecting :: SimpleEditor -> SimpleEditor
finishSelecting st =
  (maybe st 
         (\newRange -> st { selState = (selState st) { ranges = (asTuple newRange):(ranges $ selState st),
                                                       openRange = Nothing } })
         $ currentRegion st)


currentRegion :: SimpleEditor -> Maybe Range
currentRegion st =
  let selSt              = selState st
      Just rangeStartPos = openRange selSt
  in case openRange selSt of
    Just rangeStartPos ->
      let rangeStopPos = insertPos st
      in if rangeStartPos /= rangeStopPos
         then Just $ makeRange rangeStartPos rangeStopPos
         else Nothing
    Nothing -> Nothing

startOrFinishOrCancelSelecting :: SimpleEditor -> SimpleEditor
startOrFinishOrCancelSelecting st =
  let selSt = selState st
      oRange = openRange selSt
  in case oRange of
    Nothing -> startSelecting st
    Just p | p == (insertPos st) -> cancelSelecting st
           | otherwise -> finishSelecting st

applyIfReasonableSelection :: (SimpleEditor -> SimpleEditor) -> SimpleEditor -> SimpleEditor
applyIfReasonableSelection f st =
  let st' = finishSelecting st
      rs  = (ranges . selState) st'
      firstRange = rs !! 0
  in if not $ null rs
     then f st'
     else st

deleteSelection :: SimpleEditor -> SimpleEditor
deleteSelection =
  let delSel st =
        let selSt      = selState st
            rs         = ranges selSt
            firstRange = rs !! 0
            buf        = buffer st
        in (pushUndo st) { buffer    = delSelection buf firstRange,
                           selState  = selSt { ranges = drop 1 rs },
                           cursorPos = posWithinBuffer buf (fst firstRange) }
  in applyIfReasonableSelection delSel

forgetOpenRange :: SimpleEditor -> SimpleEditor
forgetOpenRange st =
  st { selState = (selState st) { openRange = Nothing } }

forgetRanges :: SimpleEditor -> SimpleEditor
forgetRanges st =
  st { selState = (selState st) { ranges = [] } }

forgetOpenRangeOrRanges :: SimpleEditor -> SimpleEditor
forgetOpenRangeOrRanges st =
  let selSt = selState st
  in case openRange selSt of
    Just _    -> forgetOpenRange st
    otherwise -> forgetRanges st

copyReasonableSelection :: GlobalState -> GlobalState
copyReasonableSelection gst =
  let ed    = finishSelecting (view editor gst)
      selSt = selState ed
      sel   = (ranges selSt) !! 0
      buf   = buffer ed
      cb    = view clipboard gst
  in if null (ranges selSt)
     then gst
     else (set clipboard ((getSelection buf sel):cb)) $ (set editor ed) gst

pasteAtInsertPos :: GlobalState -> GlobalState
pasteAtInsertPos gst
  | null (view clipboard gst) = gst
  | otherwise =
      let ed = view editor gst
          buf = buffer ed
          iPos = insertPos ed
          Pos l r = iPos
          pasteSeq = (view clipboard gst) !! 0
          lPasteSeq = Seq.length pasteSeq
          isOneLinePaste = lPasteSeq == 1
          lastLineLen = length $ Seq.index pasteSeq (lPasteSeq - 1)
      in (set editor $ (pushUndo ed) { buffer = insertLineSeqIntoBuffer buf iPos pasteSeq,
                                       cursorPos = Pos (l + (Seq.length pasteSeq) - 1)
                                                       (if isOneLinePaste then (r + lastLineLen) else lastLineLen) }) gst

tmpWriteClipboard gst = do
  writeFile "./clip.tmp" $ lineSeqToStr ((view clipboard gst) !! 0)
  return gst

