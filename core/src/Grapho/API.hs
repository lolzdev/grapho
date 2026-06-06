{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}

module Grapho.API where

import Control.Exception (bracket)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef, writeIORef)
import Foreign
import Foreign.C
import System.IO.Unsafe (unsafePerformIO)

data FTLibraryRec
data FTFaceRec
data HBFontRec
data HBBufferRec
data FcPatternRec

type FTLibrary = Ptr FTLibraryRec
type FTFace = Ptr FTFaceRec
type HBFont = Ptr HBFontRec
type HBBuffer = Ptr HBBufferRec
type FcPattern = Ptr FcPatternRec

data HBGlyphInfo = HBGlyphInfo
  { glyphCodepoint :: Word32
  }

instance Storable HBGlyphInfo where
  sizeOf _ = 20
  alignment _ = 4
  peek ptr = HBGlyphInfo <$> peekByteOff ptr 0
  poke _ _ = error "HBGlyphInfo is read-only"

data HBGlyphPosition = HBGlyphPosition
  { glyphXAdvance :: Int32
  , glyphYAdvance :: Int32
  , glyphXOffset :: Int32
  , glyphYOffset :: Int32
  }

instance Storable HBGlyphPosition where
  sizeOf _ = 20
  alignment _ = 4
  peek ptr =
    HBGlyphPosition
      <$> peekByteOff ptr 0
      <*> peekByteOff ptr 4
      <*> peekByteOff ptr 8
      <*> peekByteOff ptr 12
  poke _ _ = error "HBGlyphPosition is read-only"

data HBGlyphExtents = HBGlyphExtents
  { glyphXBearing :: Int32
  , glyphYBearing :: Int32
  , glyphWidth :: Int32
  , glyphHeight :: Int32
  }

instance Storable HBGlyphExtents where
  sizeOf _ = 16
  alignment _ = 4
  peek ptr =
    HBGlyphExtents
      <$> peekByteOff ptr 0
      <*> peekByteOff ptr 4
      <*> peekByteOff ptr 8
      <*> peekByteOff ptr 12
  poke _ _ = error "HBGlyphExtents is read-only"

data GraphoGlyph = GraphoGlyph
  { outputGlyphID :: Word32
  , outputX :: CFloat
  , outputY :: CFloat
  , outputXAdvance :: CFloat
  , outputYAdvance :: CFloat
  }

instance Storable GraphoGlyph where
  sizeOf _ = 24
  alignment _ = 4
  peek _ = error "GraphoGlyph is write-only"
  poke ptr glyph = do
    pokeByteOff ptr 0 (outputGlyphID glyph)
    pokeByteOff ptr 4 (outputX glyph)
    pokeByteOff ptr 8 (outputY glyph)
    pokeByteOff ptr 12 (outputXAdvance glyph)
    pokeByteOff ptr 16 (outputYAdvance glyph)
    pokeByteOff ptr 20 (0 :: CFloat)

foreign import ccall unsafe "FT_Init_FreeType"
  ftInitFreeType :: Ptr FTLibrary -> IO CInt

foreign import ccall unsafe "FT_Done_FreeType"
  ftDoneFreeType :: FTLibrary -> IO CInt

foreign import ccall unsafe "FT_New_Face"
  ftNewFace :: FTLibrary -> CString -> CLong -> Ptr FTFace -> IO CInt

foreign import ccall unsafe "FT_Done_Face"
  ftDoneFace :: FTFace -> IO CInt

foreign import ccall unsafe "FT_Set_Char_Size"
  ftSetCharSize :: FTFace -> CLong -> CLong -> CUInt -> CUInt -> IO CInt

foreign import ccall unsafe "hb_ft_font_create_referenced"
  hbFTFontCreateReferenced :: FTFace -> IO HBFont

foreign import ccall unsafe "hb_font_destroy"
  hbFontDestroy :: HBFont -> IO ()

foreign import ccall unsafe "hb_buffer_create"
  hbBufferCreate :: IO HBBuffer

foreign import ccall unsafe "hb_buffer_destroy"
  hbBufferDestroy :: HBBuffer -> IO ()

foreign import ccall unsafe "hb_buffer_add_utf8"
  hbBufferAddUTF8 :: HBBuffer -> CString -> CInt -> CUInt -> CInt -> IO ()

foreign import ccall unsafe "hb_buffer_guess_segment_properties"
  hbBufferGuessSegmentProperties :: HBBuffer -> IO ()

foreign import ccall unsafe "hb_shape"
  hbShape :: HBFont -> HBBuffer -> Ptr () -> CUInt -> IO ()

foreign import ccall unsafe "hb_buffer_get_length"
  hbBufferGetLength :: HBBuffer -> IO CUInt

foreign import ccall unsafe "hb_buffer_get_glyph_infos"
  hbBufferGetGlyphInfos :: HBBuffer -> Ptr CUInt -> IO (Ptr HBGlyphInfo)

foreign import ccall unsafe "hb_buffer_get_glyph_positions"
  hbBufferGetGlyphPositions :: HBBuffer -> Ptr CUInt -> IO (Ptr HBGlyphPosition)

foreign import ccall unsafe "hb_font_get_glyph_extents"
  hbFontGetGlyphExtents :: HBFont -> Word32 -> Ptr HBGlyphExtents -> IO CInt

foreign import ccall unsafe "FcNameParse"
  fcNameParse :: CString -> IO FcPattern

foreign import ccall unsafe "FcConfigSubstitute"
  fcConfigSubstitute :: Ptr () -> FcPattern -> CInt -> IO CInt

foreign import ccall unsafe "FcDefaultSubstitute"
  fcDefaultSubstitute :: FcPattern -> IO ()

foreign import ccall unsafe "FcFontMatch"
  fcFontMatch :: Ptr () -> FcPattern -> Ptr CInt -> IO FcPattern

foreign import ccall unsafe "FcPatternGetString"
  fcPatternGetString :: FcPattern -> CString -> CInt -> Ptr CString -> IO CInt

foreign import ccall unsafe "FcPatternGetInteger"
  fcPatternGetInteger :: FcPattern -> CString -> CInt -> Ptr CInt -> IO CInt

foreign import ccall unsafe "FcPatternDestroy"
  fcPatternDestroy :: FcPattern -> IO ()

configuredText :: String
configuredText = "Test abcdefghijklmnopqrstuvwxyz 1234567890"

fontSizeRef :: IORef CFloat
fontSizeRef = unsafePerformIO (newIORef 24)
{-# NOINLINE fontSizeRef #-}

resolvedFontRef :: IORef (Maybe (FilePath, Int))
resolvedFontRef = unsafePerformIO (newIORef Nothing)
{-# NOINLINE resolvedFontRef #-}

configuredFontName :: String
#if defined(darwin_HOST_OS)
configuredFontName = "Menlo"
#else
configuredFontName = "DejaVu Sans Mono"
#endif

graphoLayoutText :: Ptr () -> IO CInt
graphoLayoutText output
  | output == nullPtr = pure 1
  | otherwise = do
      fontSize <- readIORef fontSizeRef
      resolvedFont <- resolveConfiguredFont
      case resolvedFont of
        Nothing -> pure 2
        Just (fontPath, faceIndex) ->
          withCString fontPath $ \fontPathPointer ->
            withCString configuredText $ \text ->
              alloca $ \libraryPtr -> do
                initResult <- ftInitFreeType libraryPtr
                if initResult /= 0
                  then pure 3
                  else bracket (peek libraryPtr) (voidResult . ftDoneFreeType) $ \library ->
                    alloca $ \facePtr -> do
                      faceResult <- ftNewFace library fontPathPointer (fromIntegral faceIndex) facePtr
                      if faceResult /= 0
                        then pure 4
                        else bracket (peek facePtr) (voidResult . ftDoneFace) $ \face -> do
                          sizeResult <-
                            ftSetCharSize
                              face
                              0
                              (round (realToFrac fontSize * 64 :: Double))
                              72
                              72
                          if sizeResult /= 0
                            then pure 5
                            else bracket (hbFTFontCreateReferenced face) hbFontDestroy $ \font ->
                              bracket hbBufferCreate hbBufferDestroy $ \buffer -> do
                                hbBufferAddUTF8 buffer text (-1) 0 (-1)
                                hbBufferGuessSegmentProperties buffer
                                hbShape font buffer nullPtr 0
                                writeLayout font buffer fontSize output
                                pure 0

graphoZoomIn :: IO CFloat
graphoZoomIn = changeFontSize 2

graphoZoomOut :: IO CFloat
graphoZoomOut = changeFontSize (-2)

changeFontSize :: CFloat -> IO CFloat
changeFontSize delta =
  atomicModifyIORef' fontSizeRef $ \fontSize ->
    let next = max 8 (min 72 (fontSize + delta))
     in (next, next)

resolveConfiguredFont :: IO (Maybe (FilePath, Int))
resolveConfiguredFont = do
  cached <- readIORef resolvedFontRef
  case cached of
    Just font -> pure (Just font)
    Nothing -> do
      resolved <- resolveFont configuredFontName
      case resolved of
        Just font -> writeIORef resolvedFontRef (Just font)
        Nothing -> pure ()
      pure resolved

resolveFont :: String -> IO (Maybe (FilePath, Int))
resolveFont fontName =
  withCString fontName $ \fontNamePointer -> do
    patternPointer <- fcNameParse fontNamePointer
    if patternPointer == nullPtr
      then pure Nothing
      else bracket (pure patternPointer) fcPatternDestroy $ \pattern -> do
        _ <- fcConfigSubstitute nullPtr pattern 0
        fcDefaultSubstitute pattern
        alloca $ \resultPointer -> do
          matchPointer <- fcFontMatch nullPtr pattern resultPointer
          if matchPointer == nullPtr
            then pure Nothing
            else bracket (pure matchPointer) fcPatternDestroy $ \match ->
              withCString "file" $ \fileKey ->
                alloca $ \filePointer -> do
                  fileResult <- fcPatternGetString match fileKey 0 filePointer
                  if fileResult /= 0
                    then pure Nothing
                    else do
                      path <- peek filePointer >>= peekCString
                      faceIndex <-
                        withCString "index" $ \indexKey ->
                          alloca $ \indexPointer -> do
                            indexResult <- fcPatternGetInteger match indexKey 0 indexPointer
                            if indexResult == 0
                              then fromIntegral <$> peek indexPointer
                              else pure 0
                      pure (Just (path, faceIndex))

writeLayout :: HBFont -> HBBuffer -> CFloat -> Ptr () -> IO ()
writeLayout font buffer fontSize output = do
  count <- fromIntegral <$> hbBufferGetLength buffer
  infos <- hbBufferGetGlyphInfos buffer nullPtr
  positions <- hbBufferGetGlyphPositions buffer nullPtr
  glyphs <- mallocBytes (count * sizeOf (undefined :: GraphoGlyph))

  let scale value = realToFrac value / 64
      go index penX penY bounds
        | index >= count = pure (penX, bounds)
        | otherwise = do
            info <- peekElemOff infos index
            position <- peekElemOff positions index
            let xAdvance = scale (glyphXAdvance position)
                yAdvance = scale (glyphYAdvance position)
                x = penX + scale (glyphXOffset position)
                y = penY + scale (glyphYOffset position)
                glyph =
                  GraphoGlyph
                    (glyphCodepoint info)
                    x
                    y
                    xAdvance
                    yAdvance
            pokeElemOff glyphs index glyph
            nextBounds <-
              alloca $ \extentsPtr -> do
                hasExtents <- hbFontGetGlyphExtents font (glyphCodepoint info) extentsPtr
                if hasExtents == 0
                  then pure bounds
                  else do
                    extents <- peek extentsPtr
                    let left = x + scale (glyphXBearing extents)
                        right = left + scale (glyphWidth extents)
                        top = y + scale (glyphYBearing extents)
                        bottom = top + scale (glyphHeight extents)
                        glyphBounds =
                          ( min left right
                          , min bottom top
                          , max left right
                          , max bottom top
                          )
                    pure (mergeBounds bounds glyphBounds)
            go (index + 1) (penX + xAdvance) (penY + yAdvance) nextBounds

  (advanceWidth, inkBounds) <- go 0 0 0 Nothing
  let fallbackBounds = (0, -fontSize * 0.25, advanceWidth, fontSize)
      (minX, minY, inkMaxX, maxY) = maybe fallbackBounds id inkBounds
      maxX = max advanceWidth inkMaxX
      width = max 1 (maxX - minX)
      height = max 1 (maxY - minY)
      baseline = -minY
  fontName <- newCString configuredFontName

  pokeByteOff output 0 glyphs
  pokeByteOff output 8 (fromIntegral count :: CInt)
  pokeByteOff output 12 (width :: CFloat)
  pokeByteOff output 16 (height :: CFloat)
  pokeByteOff output 20 (baseline :: CFloat)
  pokeByteOff output 24 (minX :: CFloat)
  pokeByteOff output 28 (minY :: CFloat)
  pokeByteOff output 32 fontName
  pokeByteOff output 40 (fontSize :: CFloat)

mergeBounds
  :: Maybe (CFloat, CFloat, CFloat, CFloat)
  -> (CFloat, CFloat, CFloat, CFloat)
  -> Maybe (CFloat, CFloat, CFloat, CFloat)
mergeBounds Nothing bounds = Just bounds
mergeBounds (Just (minX, minY, maxX, maxY)) (nextMinX, nextMinY, nextMaxX, nextMaxY) =
  Just
    ( min minX nextMinX
    , min minY nextMinY
    , max maxX nextMaxX
    , max maxY nextMaxY
    )

graphoFreeLayout :: Ptr () -> IO ()
graphoFreeLayout output
  | output == nullPtr = pure ()
  | otherwise = do
      glyphs <- peekByteOff output 0 :: IO (Ptr GraphoGlyph)
      fontName <- peekByteOff output 32 :: IO CString
      if glyphs == nullPtr then pure () else free glyphs
      if fontName == nullPtr then pure () else free fontName
      pokeByteOff output 0 (nullPtr :: Ptr GraphoGlyph)
      pokeByteOff output 8 (0 :: CInt)
      pokeByteOff output 32 (nullPtr :: CString)

voidResult :: IO a -> IO ()
voidResult action = action >> pure ()

foreign export ccall "grapho_layout_text"
  graphoLayoutText :: Ptr () -> IO CInt

foreign export ccall "grapho_free_layout"
  graphoFreeLayout :: Ptr () -> IO ()

foreign export ccall "grapho_zoom_in"
  graphoZoomIn :: IO CFloat

foreign export ccall "grapho_zoom_out"
  graphoZoomOut :: IO CFloat
