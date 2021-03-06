{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ConstraintKinds #-}
module Bound.Unwrap ( Fresh (fresh, uname)
                    , name
                    , freshify
                    , erase
                    , nameF
                    , Counter
                    , UnwrapT
                    , Unwrap
                    , runUnwrapT
                    , runUnwrap
                    , unwrap
                    , unwrapAll) where
import Bound
import Control.Monad.Identity
import Control.Monad.Gen

data Fresh a = Fresh { fresh :: !Int
                     , uname :: a }
             deriving (Eq, Ord)

instance Show a => Show (Fresh a) where
  show (Fresh i a) = show i ++ '.' : show a

-- | Create a name. This name isn't unique at all at this point. Once
-- you have a name you can pass it to freshify to render it unique
-- within the current monadic context.
name :: a -> Fresh a
name = Fresh 0

-- | @erase@ drops the information in a 'Fresh' that makes it globally
-- unique and gives you back the user supplied name. For obvious
-- reasons, @erase@ isn't injective. It is the case that
--
-- @
--    erase . name  = id
--    name . erase /= id
-- @
erase :: Fresh a -> a
erase = uname

-- Keeping this opaque, but I don't want *another*
-- monad for counting dammit. I built one and that was enough.
newtype Counter = Counter {getCounter :: Int}

-- | A specialized version of 'GenT' used for unwrapping things.
type UnwrapT = GenT Counter
type Unwrap = Gen Counter

-- | A specialized constraint for monads who know how to unwrap
-- things.
type MonadUnwrap m = MonadGen Counter m

runUnwrapT :: Monad m => UnwrapT m a -> m a
runUnwrapT = runGenTWith (successor $ Counter . succ . getCounter)
                         (Counter 0)

runUnwrap :: Unwrap a -> a
runUnwrap = runIdentity . runUnwrapT

-- | Render a name unique within the scope of a monadic computation.
freshify :: MonadUnwrap m => Fresh a -> m (Fresh a)
freshify nm = (\i -> nm{fresh = i}) <$> fmap getCounter gen

-- | Create a name which is unique within the scope of a monadic
-- computation.
nameF :: MonadUnwrap m => a -> m (Fresh a)
nameF = freshify . name

-- | Given a scope which binds one variable, unwrap it with a
-- variable. Note that @unwrap@ will take care of @freshify@ing the
-- varable.
unwrap :: (Monad f, Functor m, MonadUnwrap m)
          => Fresh a
          -> Scope () f (Fresh a)
          -> m (Fresh a, f (Fresh a))
unwrap nm s = fmap head <$> unwrapAll nm [s]

-- | Given a list of scopes which bind one variable, unwrap them all
-- with the same variable. Note that @unwrapAll@ will take care of
-- @freshify@ing the variable.
unwrapAll :: (Monad f, MonadUnwrap m)
             => Fresh a
             -> [Scope () f (Fresh a)]
             -> m (Fresh a, [f (Fresh a)])
unwrapAll nm ss = do
  fnm <- freshify nm
  return $ (fnm, map (instantiate1 $ return fnm) ss)
