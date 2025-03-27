#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <immintrin.h>  // AVX2
#include <stdint.h>
#include <string.h>

#define WIDTH 256
#define HEIGHT 240
#define HEADERLEN 11
#define IMGSIZE 4*WIDTH*HEIGHT+HEADERLEN

static void reverse_rows_avx2(int32_t* data) {
    for (int y = 0; y < HEIGHT; y++) {
        int32_t* row = data + y * WIDTH;

        // Разворачиваем строку из 256 элементов (8 регистров AVX2)
        for (int i = 0; i < WIDTH / 2; i += 8) {
            // Загружаем 8 элементов слева и справа
            __m256i left = _mm256_loadu_si256((__m256i*)(row + i));
            __m256i right = _mm256_loadu_si256((__m256i*)(row + WIDTH - 8 - i));

            // Разворачиваем внутри регистров
            left = _mm256_permutevar8x32_epi32(left, _mm256_set_epi32(0,1,2,3,4,5,6,7));
            right = _mm256_permutevar8x32_epi32(right, _mm256_set_epi32(0,1,2,3,4,5,6,7));

            // Меняем местами левую и правую части
            _mm256_storeu_si256((__m256i*)(row + i), right);
            _mm256_storeu_si256((__m256i*)(row + WIDTH - 8 - i), left);
        }
    }
}

static int mirror_image(lua_State *state) {
    const char *img = luaL_checkstring(state, 1);
    char mirrored[IMGSIZE];
    memcpy(mirrored, img, IMGSIZE);
    reverse_rows_avx2((int32_t*)(mirrored + HEADERLEN));
    lua_pushlstring(state, mirrored, IMGSIZE);
    return 1;
}

static const struct luaL_Reg mvslib [] = {
    {"mirror_image", mirror_image},
    {NULL, NULL}  /* sentinel */
};

int luaopen_mvslib (lua_State *L) {
    luaL_openlib(L, "mvslib", mvslib, 0);
    return 1;
}