--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import Data.Monoid
import Data.List
import Data.Foldable
import Data.String
import Text.Blaze.Html
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Hakyll

postsGlob :: Pattern
postsGlob = "posts/*"
--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
  match "images/*" $ do
    route   idRoute
    compile copyFileCompiler

  match "css/*" $ do
    route   idRoute
    compile compressCssCompiler

  match "js/*" $ do
    route   idRoute
    compile copyFileCompiler

  tags <- buildTags "posts/*" (fromCapture "tags/*.html")
  match "posts/*" $ do
    route $ setExtension ".html"
    compile $ do
      let postCtx = mkPostCtx tags
      pandocCompiler
        >>= loadAndApplyTemplate "templates/post.html" postCtx
        >>= loadAndApplyTemplate "templates/base.html" postCtx
        >>= relativizeUrls
        >>= stripHTMLSuffix

  create ["index.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let indexCtx =
            listField "posts" (mkPostCtx tags) (return posts) <>
              constField "title" "All Posts"                <>
              defaultContext

      makeItem ""
          >>= loadAndApplyTemplate "templates/contents.html" indexCtx
          >>= loadAndApplyTemplate "templates/base.html" indexCtx
          >>= relativizeUrls
          >>= stripHTMLSuffix

  tagsRules tags $ \tag pattern -> do
    let title = "Tagged \"" ++ tag ++ "\""
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll pattern
      let ctx = constField "title" title <>
                  listField "posts" (mkPostCtx tags) (return posts) <>
                  defaultContext

      makeItem "" >>= loadAndApplyTemplate "templates/contents.html" ctx
                  >>= loadAndApplyTemplate "templates/base.html" ctx
                  >>= relativizeUrls
                  >>= stripHTMLSuffix

  create ["atom.xml"] $ do
      route idRoute
      compile $ do
        posts <- fmap (take 10) . recentFirst =<< loadAll "posts/*"
        let feedCtx = mkPostCtx tags
        renderAtom myFeedConfiguration feedCtx posts


  match "templates/*" $ compile templateBodyCompiler

--------------------------------------------------------------------------------

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "Chris Penner FP"
    , feedDescription = "Funcitonal Programming and other rants."
    , feedAuthorName  = "Chris Penner"
    , feedAuthorEmail = "chris@chrispenner.ca"
    , feedRoot        = "chrispenner.ca"
    }

stripHTMLSuffix :: Item String -> Compiler (Item String)
stripHTMLSuffix = return . fmap (withUrls stripSuffix)
  where stripSuffix x
          | isSuffixOf ".html" x = reverse . drop 5 . reverse $ x
          | otherwise = x

mkPostCtx :: Tags -> Context String
mkPostCtx tags = fold
  [ --tagsField "tags" tags
  tagsFieldWith getTags makeLink fold "tags" tags
  -- field "tags" $ \i -> getTags (itemIdentifier i) >>= renderTags makeLink concat
  -- tagCloudFieldWith "tags" rendTag (++) 1.0 1.0 tags
  , dateField "date" "%B %e, %Y"
  , field "nextPost" nextPostUrl
  , field "prevPost" previousPostUrl
  , defaultContext

  ]
    where
      makeLink tag (Just url) = Just $ H.a (fromString tag) ! A.class_ "tag" ! A.href (fromString ("/" ++ url))
      makeLink _  Nothing = Nothing

---------------------------------------------------------------------------------
previousPostUrl :: Item String -> Compiler String
previousPostUrl post = do
    posts <- getMatches postsGlob
    let ident = itemIdentifier post
        ident' = itemBefore posts ident
    case ident' of
        Just i -> (fmap (maybe "prev" $ toUrl) . getRoute) i
        Nothing -> return ""


nextPostUrl :: Item String -> Compiler String
nextPostUrl post = do
    posts <- getMatches postsGlob
    let ident = itemIdentifier post
        ident' = itemAfter posts ident
    case ident' of
        Just i -> (fmap (maybe "next" $ toUrl) . getRoute) i
        Nothing -> return ""

itemAfter :: Eq a => [a] -> a -> Maybe a
itemAfter xs x =
    lookup x $ zip xs (tail xs)

itemBefore :: Eq a => [a] -> a -> Maybe a
itemBefore xs x =
    lookup x $ zip (tail xs) xs

urlOfPost :: Item String -> Compiler String
urlOfPost =
    fmap (maybe "" $ toUrl) . getRoute . itemIdentifier
