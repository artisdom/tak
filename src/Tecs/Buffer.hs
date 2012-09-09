{-# LANGUAGE NoImplicitPrelude #-}

module Tecs.Buffer where

import Prelude as P
import Data.Sequence ((><), (|>), (<|))
import qualified Data.Sequence as Seq
import Data.Foldable (toList)
import Data.Monoid (mconcat)

import Tecs.Types as TT
import Tecs.Util
import Tecs.Display
import Tecs.Text

empty :: Buffer
empty = Buffer (Seq.singleton "")

handleEmptySeq :: Buffer -> Buffer
handleEmptySeq buf =
  if (lineSeq buf) == Seq.empty
  then empty
  else buf

strToBuffer :: String -> Buffer
strToBuffer s = handleEmptySeq $ Buffer (Seq.fromList (lines s))

bufferToStr :: Buffer -> String
bufferToStr buf = unlines $ bufferToLines buf

bufferToLines :: Buffer -> [String]
bufferToLines buf = toList (lineSeq buf)

lineAt :: Int -> Buffer -> String
lineAt x buf = Seq.index (lineSeq buf) x

bufferDropLines :: Int -> Buffer -> Buffer
bufferDropLines lines buffer =
  handleEmptySeq $ Buffer $ Seq.drop lines (lineSeq buffer)

posWithinBuffer :: Buffer -> Pos -> Pos
posWithinBuffer buf (Pos y x) =
  let l = clamp 0 (lastLineIdx buf) y
      r = clamp 0 (length $ lineAt l buf) x
  in Pos l r

renderBuffer :: WrapMode -> Buffer -> Int -> Int -> RenderW ()
renderBuffer wrapMode buffer height width =
  let lineStrs = linesToFixedLengthStrs wrapMode width (bufferToLines buffer)
      yPosL = [0..height - 1]
      p (yPos, str) = printStr (Pos yPos 0) str
  in do mapM p (P.zip yPosL (lineStrs ++ (repeat "")))
        return ()


insertCharIntoBuffer :: Buffer -> Pos -> Char -> Buffer
insertCharIntoBuffer buf (Pos y x) char =
  let seq = lineSeq buf
      line = Seq.index seq y
      (before, after) = P.splitAt x line
  in buf { lineSeq = Seq.update y (before ++ [char] ++ after) seq }


deleteCharFromBuffer :: Buffer -> Pos -> Buffer
deleteCharFromBuffer buf (Pos y x) =
  let seq = lineSeq buf
      line = Seq.index seq y
      (before, after) = P.splitAt x line
      newBefore = if not $ P.null before
                  then P.take (P.length before - 1) before
                  else before
  in buf { lineSeq = Seq.update y (newBefore ++ after) seq}

insertLinebreakIntoBuffer :: Buffer -> Pos -> Buffer
insertLinebreakIntoBuffer buf (Pos y x) =
  let seq = lineSeq buf
      (seqBefore, seqRest) = Seq.splitAt y seq
      seqAfter = if Seq.null seqRest
                 then Seq.empty
                 else Seq.drop 1 seqRest
      (before, after) = P.splitAt x (Seq.index seqRest 0)
      seqMiddle = Seq.fromList [before, after]
  in buf { lineSeq = (seqBefore >< seqMiddle >< seqAfter) }

numLines :: Buffer -> Int
numLines buf = Seq.length (lineSeq buf)

lastLineIdx :: Buffer -> Int
lastLineIdx buf = (numLines buf) - 1

deleteLine :: Buffer -> Int -> Buffer
deleteLine buf idx =
  let seq = lineSeq buf
      (left, right) = Seq.splitAt idx seq
  in handleEmptySeq $ buf { lineSeq = (left >< (Seq.drop 1 right)) }

concatLine :: Buffer -> Int -> Buffer
concatLine buf idx =
  let seq = lineSeq buf
      (left, right) = Seq.splitAt (idx - 1) seq
      concatted = (Seq.index right 0) ++ (Seq.index right 1)
  in if idx <= 0 || (Seq.length right) < 2
     then buf
     else buf { lineSeq = (left |> concatted) >< (Seq.drop 2 right) }

getSelection :: Buffer -> (Pos, Pos) -> Seq.Seq String
getSelection buf (start, end) =
  let realStart = posWithinBuffer buf start
      realEnd   = posWithinBuffer buf end
      isOneLine = (line realStart) == (line realEnd)
      firstLine = lineAt (line realStart) buf
  in if isOneLine
     then let nMidChars = (row realEnd) - (row realStart)
          in Seq.singleton $ P.take nMidChars $ P.drop (row realStart) firstLine
     else let lastLine  = lineAt (line realEnd) buf
              nMidLines = (line realEnd) - (line realStart)
              firstMidlineIdx = (line realStart) + 1
              seq       = lineSeq buf
              midLines  = Seq.take nMidLines $ Seq.drop firstMidlineIdx seq
              cFirstLine = P.drop (row realStart) firstLine
              cLastLine  = P.take (row realEnd) lastLine
          in (((cFirstLine <| midLines) |> cLastLine))

delSelection :: Buffer -> (Pos, Pos) -> Buffer
delSelection buf (start, end) =
  let realStart = posWithinBuffer buf start
      realEnd   = posWithinBuffer buf end
      isOneLine = (line realStart) == (line realEnd)
      firstLine = lineAt (line realStart) buf
      seq       = lineSeq buf
  in if isOneLine
     then let before = P.take (row realStart) firstLine
              after  = P.drop (row realEnd) firstLine
          in buf { lineSeq = Seq.update (line realStart) (before ++ after) seq }
     else let linesBefore    = Seq.take ((line realStart) - 1) seq
              lastLineBefore = P.take (row realStart) $ Seq.index seq (line realStart)
              linesAfter     = Seq.drop ((line realEnd) + 1) seq
              firstLineAfter = P.drop (row realEnd) $ Seq.index seq (line realEnd)
              midLine        = lastLineBefore ++ firstLineAfter
          in Buffer (((linesBefore |> midLine) >< linesAfter))

insertLineSeqIntoBuffer :: Buffer -> Pos -> Seq.Seq String -> Buffer
insertLineSeqIntoBuffer buf pos inSeq =
  let Pos l r   = posWithinBuffer buf pos
      seq       = lineSeq buf
      seqBefore = Seq.take (l - 1) seq
      seqAfter  = Seq.drop (l + 1) seq
      line      = Seq.index seq l
      lineBefore = P.take r line
      lineAfter  = P.drop r line
  in case Seq.length inSeq of
     0 -> buf
     1 -> buf { lineSeq = mconcat [seqBefore,
                                   Seq.singleton (lineBefore ++ (Seq.index inSeq 0) ++ lineAfter),
                                   seqAfter] }
     otherwise ->
         let firstLine = Seq.index inSeq 0
             lastLine  = Seq.index inSeq ((Seq.length inSeq) - 1)
             midLines  = Seq.drop 1 $ Seq.take ((Seq.length inSeq) - 1) inSeq
         in buf { lineSeq = mconcat [seqBefore,
                                     Seq.singleton (lineBefore ++ firstLine),
                                     midLines,
                                     Seq.singleton (lastLine ++ lineAfter),
                                     seqAfter] }

