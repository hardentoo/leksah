{-# OPTIONS_GHC
    -XExistentialQuantification
    -XMultiParamTypeClasses
    -XFunctionalDependencies #-}
-----------------------------------------------------------------------------
--
-- Module      :  IDE.Core.Panes
-- Copyright   :  (c) Juergen Nicklisch-Franken, Hamish Mackenzie
-- License     :  GNU-GPL
--
-- Maintainer  :  <maintainer at leksah.org>
-- Stability   :  provisional
-- Portability :  portable
--
-- | The basic definitions for all panes
--
-------------------------------------------------------------------------------

module Graphics.UI.Frame.Panes (

-- * Panes and pane layout
    PaneMonad(..)
,   Pane(..)
,   IDEPane(..)
,   RecoverablePane(..)
,   PaneDirection(..)
,   PanePathElement(..)
,   PanePath
,   PaneLayout(..)
,   PaneGroupWindow(..)
,   PaneGroup(..)
,   PaneName
,   Connection(..)
,   Connections
,   StandardPath
,   signalDisconnectAll
) where

import Graphics.UI.Gtk hiding (get)
import System.Glib.GObject
import System.Glib.Signals
import Data.Maybe
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Typeable
import Control.Monad.Trans

-- ---------------------------------------------------------------------
-- Panes and pane layout
--

--
-- | A path to a pane
--
type PanePath       =   [PanePathElement]

--
-- | An element of a path to a pane
--
data PanePathElement = SplitP PaneDirection | GroupP String
    deriving (Eq,Show,Read)

--
-- | The relative direction to a pane from the parent
--
data PaneDirection  =   TopP | BottomP | LeftP | RightP
    deriving (Eq,Show,Read)
  	
--
-- | Description of a window layout
-- Horizontal: top bottom Vertical: left right
--
data PaneLayout =       HorizontalP PaneLayout PaneLayout Int
                    |   VerticalP PaneLayout PaneLayout Int
                    |   TerminalP {
                                paneGroups   :: PaneGroups
                            ,   paneTabs     :: (Maybe PaneDirection)
                            ,   currentPage  :: Int
                            ,   detachedId   :: Maybe String
                            ,   detachedSize :: Maybe (Int, Int) }
    deriving (Eq,Show,Read)

data PaneGroupWindow = PaneGroupWindow {
    groupWindowSize :: (Int, Int)
} deriving (Eq,Show,Read)

data PaneGroup = PaneGroup {
        paneGroupLayout :: PaneLayout
--    ,   paneGroupWindow :: Maybe PaneGroupWindow
} deriving (Eq,Show,Read)

type PaneGroups = Map.Map String PaneGroup

--
-- | All kinds of panes are instances of pane
--

class (Typeable alpha, PaneMonad beta) => Pane alpha beta | alpha -> beta where
    paneName        ::   alpha -> PaneName
    paneName b      =   if getAddedIndex b == 0
                            then primPaneName b
                            else primPaneName b ++ "(" ++ show (getAddedIndex b) ++ ")"
    primPaneName    ::   alpha -> String
    getAddedIndex   ::   alpha -> Int
    getAddedIndex _ =   0
    getTopWidget    ::   alpha -> Widget
    paneId          ::   alpha -> String
    makeActive      ::   alpha -> beta ()
--    makeActive _    =    return ()
    close           ::   alpha -> beta ()

class (Pane alpha delta, Read beta, Show beta, Typeable beta, PaneMonad delta)
                    => RecoverablePane alpha beta delta | beta -> alpha, alpha -> beta where
    saveState       ::   alpha -> delta  (Maybe beta)
    recoverState    ::   PanePath -> beta -> delta ()

type PaneName = String

data IDEPane delta       =   forall alpha beta. (RecoverablePane alpha beta delta) => PaneC alpha

instance Eq (IDEPane delta) where
    (== ) (PaneC x) (PaneC y) = paneName x == paneName y

instance Ord (IDEPane delta) where
    (<=) (PaneC x) (PaneC y) = paneName x <=  paneName y

instance Show (IDEPane delta) where
    show (PaneC x)    = "Pane " ++ paneName x

type StandardPath = PanePath


class MonadIO delta =>  PaneMonad delta where
    getWindowsSt    ::   delta [Window]
    setWindowsSt    ::   [Window] -> delta ()
    getUIManagerSt  ::   delta UIManager

    getPanesSt      ::   delta (Map PaneName (IDEPane delta))
    setPanesSt      ::   Map PaneName (IDEPane delta) -> delta ()

    getPaneMapSt    ::   delta (Map PaneName (PanePath, Connections))
    setPaneMapSt    ::   Map PaneName (PanePath, Connections) -> delta ()

    getActivePaneSt ::   delta (Maybe (PaneName, Connections))
    setActivePaneSt ::   Maybe (PaneName, Connections) -> delta ()

    getLayoutSt     ::   delta PaneLayout
    setLayoutSt     ::   PaneLayout -> delta ()

    runInIO         ::   forall beta. (beta -> delta()) -> delta (beta -> IO ())


--
-- | Signal handlers for the different pane types
--
data Connection =  forall alpha . GObjectClass alpha => ConnectC (ConnectId alpha)

type Connections = [Connection]

signalDisconnectAll :: Connections -> IO ()
signalDisconnectAll = mapM_ (\ (ConnectC s) -> signalDisconnect s)



