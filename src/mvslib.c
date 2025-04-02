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
#define MAX_TOKENS 20
#define MAX_TOKEN_LEN 512

typedef struct {
    char *prefix;
    char *command;
    char *params[MAX_TOKENS];
    int param_count;
    char *tags;
} IRCMessage;

void free_irc_message(IRCMessage *msg) {
    if (msg->prefix) free(msg->prefix);
    if (msg->command) free(msg->command);
    if (msg->tags) free(msg->tags);
    for (int i = 0; i < msg->param_count; i++) {
        if (msg->params[i]) free(msg->params[i]);
    }
}

static IRCMessage* _parse_irc_message(const char *line) {
    IRCMessage *msg = calloc(1, sizeof(IRCMessage));
    if (!msg) return NULL;

    char *copy = strdup(line);
    if (!copy) {
        free(msg);
        return NULL;
    }

    char *ptr = copy;

    // Парсим IRCv3 tags (если есть, начинаются с '@')
    if (*ptr == '@') {
        char *tags_end = strchr(ptr, ' ');
        if (!tags_end) {
            free(copy);
            free_irc_message(msg);
            return NULL;
        }
        *tags_end = '\0';
        msg->tags = strdup(ptr + 1);  // Пропускаем '@'
        ptr = tags_end + 1;
    }

    // Парсим префикс (начинается с ':')
    if (*ptr == ':') {
        ptr++;
        char *prefix_end = strchr(ptr, ' ');
        if (!prefix_end) {
            free(copy);
            free_irc_message(msg);
            return NULL;
        }
        *prefix_end = '\0';
        msg->prefix = strdup(ptr);
        ptr = prefix_end + 1;
    }

    // Парсим команду (до первого пробела)
    char *cmd_end = strchr(ptr, ' ');
    if (cmd_end) {
        *cmd_end = '\0';
        msg->command = strdup(ptr);
        ptr = cmd_end + 1;
    } else {
        // Команда без параметров
        msg->command = strdup(ptr);
        free(copy);
        return msg;
    }

    // Парсим параметры
    while (*ptr && msg->param_count < MAX_TOKENS) {
        if (*ptr == ':') {
            // Последний параметр (может содержать пробелы)
            ptr++;
            msg->params[msg->param_count++] = strdup(ptr);
            break;
        } else {
            // Обычный параметр
            char *param_end = strchr(ptr, ' ');
            if (param_end) {
                *param_end = '\0';
                msg->params[msg->param_count++] = strdup(ptr);
                ptr = param_end + 1;
            } else {
                msg->params[msg->param_count++] = strdup(ptr);
                break;
            }
        }
    }

    free(copy);
    return msg;
}

static int parse_irc_message(lua_State *state) {
    const char *message = luaL_checkstring(state, 1);
    IRCMessage *parsed = _parse_irc_message(message);
    if (!parsed) {
        lua_pushnil(state);
        return 1;
    }
    int idx = 1;
    lua_createtable(state, 5 + parsed->param_count, 0);
    const char* parts[] = {parsed->tags, parsed->prefix, parsed->command};
    for (int i=0; i<3; i++) {
        if (parts[i]) {
            lua_pushstring(state, parts[i]);
        } else {
            lua_pushstring(state, "");
        }
        lua_rawseti(state, -2, idx++);
    }
    for (int i=0; i<parsed->param_count; ++i) {
        lua_pushstring(state, parsed->params[i]);
        lua_rawseti(state, -2, idx++);
    }
    free_irc_message(parsed);
    return 1;
}

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
    {"parse_irc_message", parse_irc_message},
    {NULL, NULL}  /* sentinel */
};

int luaopen_mvslib (lua_State *L) {
    luaL_openlib(L, "mvslib", mvslib, 0);
    return 1;
}