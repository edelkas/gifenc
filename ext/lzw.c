/*
  LZW encoding code courtesy of Daniel Löbl <dloebl.2000@gmail.com>
  Full source: https://github.com/dloebl/cgif
*/

#include "main.h"

#define MAX_CODE_LEN 12
#define MAX_DICT_LEN (1uL << MAX_CODE_LEN)
#define BLOCK_SIZE 0xFF

typedef struct
{
  uint8_t *pRasterData;
  uint32_t sizeRasterData;
} LZWResult;

typedef struct
{
  uint16_t *pTreeInit;
  uint16_t *pTreeList;
  uint16_t *pTreeMap;
  uint16_t *pLZWData;
  const uint8_t *pImageData;
  uint32_t numPixel;
  uint32_t LZWPos;
  uint16_t dictPos;
  uint16_t mapPos;
} LZWGenState;

static uint8_t calcNextPower2Ex(uint16_t n)
{
  uint8_t nextPow2;

  for (nextPow2 = 0; n > (1uL << nextPow2); ++nextPow2);
  return nextPow2;
}

static uint8_t calcInitCodeLen(uint16_t numEntries)
{
  uint8_t index;

  index = calcNextPower2Ex(numEntries);
  return (index < 3) ? 3 : index + 1;
}

static void resetDict(LZWGenState *pContext, const uint16_t initDictLen)
{
  pContext->dictPos = initDictLen + 2;
  pContext->mapPos = 1;
  pContext->pLZWData[pContext->LZWPos] = initDictLen;
  ++(pContext->LZWPos);

  memset(pContext->pTreeInit, 0, initDictLen * sizeof(uint16_t) * initDictLen);
  memset(pContext->pTreeList, 0, ((sizeof(uint16_t) * 2) + sizeof(uint16_t)) * MAX_DICT_LEN);
}

static void add_child(LZWGenState *pContext, const uint16_t parentIndex, const uint16_t LZWIndex, const uint16_t initDictLen, const uint8_t nextColor)
{
  uint16_t *pTreeList;
  uint16_t mapPos;

  pTreeList = pContext->pTreeList;
  mapPos = pTreeList[parentIndex * (2 + 1)];
  if (!mapPos)
  {
    if (pTreeList[parentIndex * (2 + 1) + 2])
    {
      mapPos = pContext->mapPos;

      memset(pContext->pTreeMap + ((mapPos - 1) * initDictLen), 0, initDictLen * sizeof(uint16_t));
      pContext->pTreeMap[(mapPos - 1) * initDictLen + nextColor] = LZWIndex;
      pTreeList[parentIndex * (2 + 1)] = mapPos;
      ++(pContext->mapPos);
    }
    else
    {
      pTreeList[parentIndex * (2 + 1) + 1] = nextColor;
      pTreeList[parentIndex * (2 + 1) + 2] = LZWIndex;
    }
  }
  else
  {
    pContext->pTreeMap[(mapPos - 1) * initDictLen + nextColor] = LZWIndex;
  }
  ++(pContext->dictPos);
}

static int lzw_crawl_tree(LZWGenState *pContext, uint32_t *pStrPos, uint16_t parentIndex, const uint16_t initDictLen)
{
  uint16_t *pTreeInit;
  uint16_t *pTreeList;
  uint32_t strPos;
  uint16_t nextParent;
  uint16_t mapPos;

  if (parentIndex >= initDictLen)
  {
    return 1;
  }
  pTreeInit = pContext->pTreeInit;
  pTreeList = pContext->pTreeList;
  strPos = *pStrPos;

  if (strPos < (pContext->numPixel - 1))
  {
    if (pContext->pImageData[strPos + 1] >= initDictLen)
    {
      return 1;
    }
    nextParent = pTreeInit[parentIndex * initDictLen + pContext->pImageData[strPos + 1]];
    if (nextParent)
    {
      parentIndex = nextParent;
      ++strPos;
    }
    else
    {
      pContext->pLZWData[pContext->LZWPos] = parentIndex;
      ++(pContext->LZWPos);
      if (pContext->dictPos < MAX_DICT_LEN)
      {
        pTreeInit[parentIndex * initDictLen + pContext->pImageData[strPos + 1]] = pContext->dictPos;
        ++(pContext->dictPos);
      }
      else
      {
        resetDict(pContext, initDictLen);
      }
      ++strPos;
      *pStrPos = strPos;
      return 0;
    }
  }

  while (strPos < (pContext->numPixel - 1))
  {
    if (pContext->pImageData[strPos + 1] >= initDictLen)
    {
      return 1;
    }

    if (pTreeList[parentIndex * (2 + 1) + 2] && pTreeList[parentIndex * (2 + 1) + 1] == pContext->pImageData[strPos + 1])
    {
      parentIndex = pTreeList[parentIndex * (2 + 1) + 2];
      ++strPos;
      continue;
    }

    mapPos = pContext->pTreeList[parentIndex * (2 + 1)];
    if (mapPos)
    {
      nextParent = pContext->pTreeMap[(mapPos - 1) * initDictLen + pContext->pImageData[strPos + 1]];
      if (nextParent)
      {
        parentIndex = nextParent;
        ++strPos;
        continue;
      }
    }

    pContext->pLZWData[pContext->LZWPos] = parentIndex;
    ++(pContext->LZWPos);
    if (pContext->dictPos < MAX_DICT_LEN)
    {
      add_child(pContext, parentIndex, pContext->dictPos, initDictLen, pContext->pImageData[strPos + 1]);
    }
    else
    {

      resetDict(pContext, initDictLen);
    }
    ++strPos;
    *pStrPos = strPos;
    return 0;
  }
  pContext->pLZWData[pContext->LZWPos] = parentIndex;
  ++(pContext->LZWPos);
  ++strPos;
  *pStrPos = strPos;
  return 0;
}

static int lzw_generate(LZWGenState *pContext, uint16_t initDictLen)
{
  uint32_t strPos;
  int r;
  uint8_t parentIndex;

  strPos = 0;
  resetDict(pContext, initDictLen);
  while (strPos < pContext->numPixel)
  {
    parentIndex = pContext->pImageData[strPos];

    r = lzw_crawl_tree(pContext, &strPos, (uint16_t)parentIndex, initDictLen);
    if (r != 0)
    {
      return r;
    }
  }
  pContext->pLZWData[pContext->LZWPos] = initDictLen + 1;
  ++(pContext->LZWPos);
  return 0;
}

static uint32_t create_byte_list(uint8_t *byteList, uint32_t lzwPos, uint16_t *lzwStr, uint16_t initDictLen, uint8_t initCodeLen)
{
  uint32_t i;
  uint32_t dictPos;
  uint16_t n = 2 * initDictLen;
  uint32_t bytePos = 0;
  uint8_t bitOffset = 0;
  uint8_t lzwCodeLen = initCodeLen;
  int correctLater = 0;

  byteList[0] = 0;

  dictPos = 1;
  for (i = 0; i < lzwPos; ++i)
  {
    if ((lzwCodeLen < MAX_CODE_LEN) && ((uint32_t)(n - (initDictLen)) == dictPos))
    {
      ++lzwCodeLen;
      n *= 2;
    }
    correctLater = 0;
    byteList[bytePos] |= ((uint8_t)(lzwStr[i] << bitOffset));
    if (lzwCodeLen + bitOffset >= 8)
    {
      if (lzwCodeLen + bitOffset == 8)
      {
        byteList[++bytePos] = 0;
        correctLater = 1;
      }
      else if (lzwCodeLen + bitOffset < 16)
      {
        byteList[++bytePos] = (uint8_t)(lzwStr[i] >> (8 - bitOffset));
      }
      else if (lzwCodeLen + bitOffset == 16)
      {
        byteList[++bytePos] = (uint8_t)(lzwStr[i] >> (8 - bitOffset));
        byteList[++bytePos] = 0;
        correctLater = 1;
      }
      else
      {
        byteList[++bytePos] = (uint8_t)(lzwStr[i] >> (8 - bitOffset));
        byteList[++bytePos] = (uint8_t)(lzwStr[i] >> (16 - bitOffset));
      }
    }
    bitOffset = (lzwCodeLen + bitOffset) % 8;
    ++dictPos;
    if (lzwStr[i] == initDictLen)
    {
      lzwCodeLen = initCodeLen;
      n = 2 * initDictLen;
      dictPos = 1;
    }
  }

  if (correctLater)
  {
    --bytePos;
  }
  return bytePos;
}

static uint32_t create_byte_list_block(uint8_t *byteList, uint8_t *byteListBlock, const uint32_t numBytes)
{
  uint32_t i;
  uint32_t numBlock = numBytes / BLOCK_SIZE;
  uint8_t numRest = numBytes % BLOCK_SIZE;

  for (i = 0; i < numBlock; ++i)
  {
    byteListBlock[i * (BLOCK_SIZE + 1)] = BLOCK_SIZE;
    memcpy(byteListBlock + 1 + i * (BLOCK_SIZE + 1), byteList + i * BLOCK_SIZE, BLOCK_SIZE);
  }
  if (numRest > 0)
  {
    byteListBlock[numBlock * (BLOCK_SIZE + 1)] = numRest;
    memcpy(byteListBlock + 1 + numBlock * (BLOCK_SIZE + 1), byteList + numBlock * BLOCK_SIZE, numRest);
    byteListBlock[1 + numBlock * (BLOCK_SIZE + 1) + numRest] = 0;
    return 1 + numBlock * (BLOCK_SIZE + 1) + numRest;
  }

  byteListBlock[numBlock * (BLOCK_SIZE + 1)] = 0;
  return numBlock * (BLOCK_SIZE + 1);
}

static int LZW_GenerateStream(LZWResult *pResult, const uint32_t numPixel, const uint8_t *pImageData, const uint16_t initDictLen, const uint8_t initCodeLen)
{
  LZWGenState *pContext;
  uint32_t lzwPos, bytePos;
  uint32_t bytePosBlock;
  int r;

  pContext = malloc(sizeof(LZWGenState));
  pContext->pTreeInit = malloc((initDictLen * sizeof(uint16_t)) * initDictLen);
  pContext->pTreeList = malloc(((sizeof(uint16_t) * 2) + sizeof(uint16_t)) * MAX_DICT_LEN);
  pContext->pTreeMap = malloc(((MAX_DICT_LEN / 2) + 1) * (initDictLen * sizeof(uint16_t)));
  pContext->numPixel = numPixel;
  pContext->pImageData = pImageData;
  pContext->pLZWData = malloc(sizeof(uint16_t) * (numPixel + 2));
  pContext->LZWPos = 0;

  r = lzw_generate(pContext, initDictLen);
  if (r != 0)
  {
    goto LZWGENERATE_Cleanup;
  }
  lzwPos = pContext->LZWPos;

  uint8_t *byteList;
  uint8_t *byteListBlock;
  uint64_t MaxByteListLen = MAX_CODE_LEN * lzwPos / 8ul + 2ul + 1ul;
  uint64_t MaxByteListBlockLen = MAX_CODE_LEN * lzwPos * (BLOCK_SIZE + 1ul) / 8ul / BLOCK_SIZE + 2ul + 1ul + 1ul;
  byteList = malloc(MaxByteListLen);
  byteListBlock = malloc(MaxByteListBlockLen);
  bytePos = create_byte_list(byteList, lzwPos, pContext->pLZWData, initDictLen, initCodeLen);
  bytePosBlock = create_byte_list_block(byteList, byteListBlock, bytePos + 1);
  free(byteList);
  pResult->sizeRasterData = bytePosBlock + 1;
  pResult->pRasterData = byteListBlock;
LZWGENERATE_Cleanup:
  free(pContext->pLZWData);
  free(pContext->pTreeInit);
  free(pContext->pTreeList);
  free(pContext->pTreeMap);
  free(pContext);
  return r;
}

/* LZW-encode a binary string honoring GIF's specs and build a Ruby string */
VALUE lzw_encode(VALUE self, VALUE data)
{
  // Parse input
  if (!RB_TYPE_P(data, T_STRING))
    rb_raise(rb_eRuntimeError, "No data to LZW encode.");
  uint8_t *str = (uint8_t*)RSTRING_PTR(data);
  long len = RSTRING_LEN(data);

  // Encode data
  LZWResult encResult;
  uint8_t initCodeLen = calcInitCodeLen(256);
  uint16_t initDictLen = 1uL << (initCodeLen - 1);
  LZW_GenerateStream(&encResult, len, str, initDictLen, initCodeLen);

  // Build output
  return rb_str_new((const char*) encResult.pRasterData, encResult.sizeRasterData);
}