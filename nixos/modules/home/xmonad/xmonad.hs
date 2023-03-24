{-# OPTIONS_GHC -Wno-deprecations #-}

import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.DynamicProperty
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.InsertPosition
import XMonad.Util.Run (spawnPipe)
import XMonad.Util.EZConfig (additionalKeys)
import XMonad.Prompt
import System.IO
import Data.Monoid ((<>))
import qualified Data.Map as M
import qualified XMonad.StackSet as W
import XMonad.Actions.Minimize
import XMonad.Layout.Minimize
import qualified XMonad.Layout.BoringWindows as BW
import XMonad.Actions.Navigation2D
import XMonad.Actions.Minimize
import XMonad.Layout.Minimize
import XMonad.Util.CustomKeys

import XMonad.Layout.BinarySpacePartition
import XMonad.Layout.Spacing
import XMonad.Layout.ThreeColumns
import XMonad.Actions.Navigation2D

import qualified Graphics.X11.Types as XT

-- import MyKeys

main :: IO ()
main = do
  xmproc <- spawnPipe "xmobar"
  xmonad =<< xmobar myConfig

backgroundColor = "#000000"
middleColor     = "#343434"
foregroundColor = "#555555"

myConfig = def
    { borderWidth = 1
    , manageHook = insertPosition Below Newer <+> manageDocks <+> manageHook def
    , layoutHook = minimize . BW.boringWindows $ avoidStruts $ spacingWithEdge 2 emptyBSP ||| spacingWithEdge 2 (ThreeCol 1 (3/100) (-1/3))
    , handleEventHook = mconcat [ docksEventHook , handleEventHook def ]
    , logHook = dynamicLogWithPP xmobarPP { ppTitle = xmobarColor "green" "" . shorten 50 }
    , modMask = mod4Mask
    , terminal = "urxvt"
    , focusedBorderColor = foregroundColor
    , normalBorderColor = middleColor
    , keys = myKeys
    }

-- myConfig = def
--     { handleEventHook = dynamicPropertyChange "WM_NAME" myDynHook <+> handleEventHook def
--     }

-- myDynHook = composeOne [ title =? "*scratch*" -?> doRectFloat (W.RationalRect 0.25 0.25 0.5 0.5) ]
-- Some event

myKeys = customKeys removedKeys addedKeys

removedKeys :: XConfig l -> [(KeyMask, KeySym)]
removedKeys _ = []

addedKeys :: XConfig l -> [((KeyMask, KeySym), X ())]
addedKeys conf@(XConfig { XMonad.modMask = modMask }) = [
              -- Terminal
              ((modMask, xK_Return), spawn $ XMonad.terminal conf)

              -- Close window
            , ((modMask, xK_q), kill)

              -- Application launcher
            , ((modMask, xK_d), spawn "rofi -show run")

              -- Launch Emacs
            , ((modMask .|. shiftMask, xK_e), spawn "emacsclient -c -a emacs")

              -- Launch Internet Browser
            , ((modMask .|. shiftMask, xK_i), spawn "firefox")

              -- Launch Inbox
            , ((modMask, xK_i), spawn "emacsclient -c -a emacs ~/org/inbox.org")

              -- Restart xmonad
            , ((modMask, xK_r), restart "xmonad" True)

              -- Lock screen
            , ((modMask, xK_o), spawn "xscreensaver-command -lock")

              -- Screenshot 1
            , ((controlMask, xK_Print), spawn "sleep 0.2; scrot -s")

              -- Screenshot 2
            , ((0, xK_Print), spawn "scrot")

              -- Minimize
            , ((modMask,               xK_m     ), withFocused minimizeWindow      )
              -- Maximize
            , ((modMask .|. shiftMask, xK_m     ), withLastMinimized maximizeWindow)
            ]
