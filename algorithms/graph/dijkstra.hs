{-# LANGUAGE CPP                 #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-deferred-type-errors #-}
{-# OPTIONS_GHC -Wincomplete-patterns #-}

module Dijkstra where

import           Control.Monad.ST
import           Data.Foldable
import           Data.List
import           Data.Maybe
import           Data.STRef

-- ------------------------------------------------------------------------------

-- little priority queue.
-- we maintain a mean heap of DistanceEntry: each nodes and their distance
-- to starting node.
data SkewHeap a = Empty | SkewNode a (SkewHeap a) (SkewHeap a) deriving (Show, Eq)

instance Functor SkewHeap where
  fmap f Empty              = Empty
  fmap f (SkewNode x h1 h2) = SkewNode (f x) (fmap f h1) (fmap f h2)

instance Applicative SkewHeap where
  pure x = SkewNode x Empty Empty
  (<*>) = error "no"

instance (Ord a) => Semigroup(SkewHeap a) where
  heap1@(SkewNode x1 l1 r1) <> heap2@(SkewNode x2 l2 r2)
    | x1 <= x2 = SkewNode x1 (heap2 <> r1) l1
    | otherwise = SkewNode x2 (heap1 <> r2) l2
  Empty <> heap = heap
  heap <> Empty = heap

instance (Ord a) => Monoid (SkewHeap a) where
  mempty = Empty

-- implement
instance Foldable SkewHeap where
  foldr _ b Empty            = b
  foldr f b (SkewNode x l r) = f x (foldr f (foldr f b l) r)

-- instance Traversable SkewHeap where
instance Traversable SkewHeap where
  traverse _ Empty = pure Empty
  traverse f (SkewNode x l r) = SkewNode <$> f x <*> traverse f l <*> traverse f r


-- a -> f b -> t a -> f (t b)
-- traverse f (x:xs) = (fmap (f a : ) traverse f xs)

extractMin :: (Ord a) => SkewHeap a -> Maybe (a, SkewHeap a)
extractMin Empty            = Nothing
extractMin (SkewNode x l r) = Just (x, l <> r)

-- true logn

-- can only delete by key
-- heapDelete :: (Ord a) => a -> SkewHeap a -> SkewHeap a
-- heapDelete = heapDeleteBy id (const True)

-- delete by a key and a predicate.
-- a node will only be deleted if both key and predicates are satisfied.
heapDeleteBy :: forall a. (Ord a)
             => (a -> Bool) -- whether delete the node if hit the key
             -> SkewHeap a
             -> Maybe ([a], SkewHeap a)
heapDeleteBy pred h = runST $ do
  ref <- newSTRef []
  h' <- go (\x -> modifySTRef ref (x:)) h
  acc <- readSTRef ref
  return $ Just (acc, h')
  where
    go :: (Monad m) => (a -> m ()) -> SkewHeap a -> m (SkewHeap a)
    go _ Empty              = pure Empty
    go modify t@(SkewNode x l r) =
      if pred x
         then modify x >> (<>) <$> go modify l <*> go modify r
           else do
             l' <- go modify l
             SkewNode x l' <$> go modify r


-- update a node that satisfied the preidcate.
heapModify :: Ord a => (a -> Bool) -> (a -> a) -> SkewHeap a -> SkewHeap a
heapModify pred f h = case heapDeleteBy pred h of
                        Nothing       -> h
                        Just (xs, h') -> mconcat (fmap (pure . f) xs) <> h'

-- find node by predicate and retreive information from the node with get
heapFind :: (a -> Bool) -> (a -> k) -> SkewHeap a -> Maybe k
heapFind pred get h = let hs = foldl' (flip (:)) [] h
                     in case filter pred hs of
                          []   -> Nothing
                          [x]  -> Just (get x)
                          x:xs -> Just (get x)

-- ------------------------------------------------------------------------------

newtype Vertex = Vertex String deriving (Show, Eq)

instance Ord Vertex where
  compare _ _ = EQ


type Neighbours = (Vertex, [(Vertex, Weight)])

type Weight = Int
type Graph = [Neighbours]

data DistanceEntry = DistanceEntry
  { vertex   :: Vertex
  , distance :: Int   -- distance from the source vertex.
  , prev     :: Maybe Vertex
  }
  deriving (Show, Eq)

instance Ord DistanceEntry where
  compare a b = compare (distance a) (distance b)

type DistanceTable = [DistanceEntry]

initTable :: Vertex -> Graph -> DistanceTable
initTable (Vertex s) = map (\(v@(Vertex lbl), _) ->
  DistanceEntry { vertex = v
                , distance = if lbl == s then 0 else maxBound :: Int
                , prev = Nothing
                })

-- ------------------------------------------------------------------------------

update :: (Eq key) => (key, value) -> [(key, value)] -> [(key, value)]
update (k, v) xs = (k, v) : filter (\(k', _) -> k' /= k) xs

-- do we need to rebuild a min heap everytime?
-- no? if so why not just sort.

-- ok first we add all nodes to the queue.
-- at the beginning s will be at the top. with d(s) = 0;
-- then we relax each neigbour of the min, update the queue for any changes
--
-- how to update? first remove old nodes from the queue, then just
-- add the new node to the tree with the old node removed.
--
-- recurse until the queue is empty.


dijkstra :: Vertex -> Graph -> DistanceTable
dijkstra v graph = foldr (:) [] (search queue)
  where
    queue = foldl' (<>) Empty (fmap pure (initTable v graph))
    search :: SkewHeap DistanceEntry -> SkewHeap DistanceEntry
    search table | table == Empty = table
      | otherwise =
        case extractMin table of
          Nothing -> table
          Just (v, t') ->
            let k = vertex v
                dv = distance v
                adjs = lookup k graph
             in case adjs of
                  Nothing -> error "never happen"
                  Just us -> foldl'
                    (\h (uk, uv) ->
                      heapModify ((uk ==) . vertex)
                      (\e -> e { distance = dv + uv }) h) table us


-- ------------------------------------------------------------------------------

#define TEST
#ifdef TEST

-- test input
-- A E D C B
testHeadModify :: IO ()
testHeadModify = do
  let h1 = heapModify (pred "B") (\e -> e { distance = 10 }) queue
      h2 = heapModify (pred "C") (\e -> e { distance = 8 }) h1
      h3 = heapModify (pred "D") (\e -> e { distance = 3 }) h2
      h4 = heapModify (pred "E") (\e -> e { distance = 2 }) h3
  print h4
  let Just (a, xs) = extractMin h4
  print a
  let Just (a, xs') = extractMin xs
  print a
  let Just (a, xs) = extractMin xs'
  print a
  let Just (a, xs') = extractMin xs
  print a
  let Just (a, xs) = extractMin xs'
  print a
 where
   pred l = (\(Vertex v) -> v == l) . vertex
   v = Vertex "A"
   queue = foldl' (<>) Empty (fmap pure (initTable v graph))

-- tester
--  A-6--B
--  |   /| \ 5
--  1  2 |  C
--  | /  | / 5
--  D-1- E

graph :: Graph
graph = [ (Vertex "A", [ (Vertex "B", 6)
                       , (Vertex "D", 1)])
        , (Vertex "B",  [ (Vertex "A", 6)
                        , (Vertex "D", 2)
                        , (Vertex "E", 2)
                       ])
        , (Vertex "C", [ (Vertex "B", 5)
                        , (Vertex "E", 5)
                       ])
        , (Vertex "D", [ (Vertex "A", 1)
                       , (Vertex "B", 2)
                       , (Vertex "E", 1)])
        , (Vertex "E", [ (Vertex "D", 1)
                       , (Vertex "B", 2)
                       , (Vertex "C", 5)])
        ]

testDijkstra :: IO ()
testDijkstra = do
  let s = Vertex "A"
      q = dijkstra s graph
  print q


#endif