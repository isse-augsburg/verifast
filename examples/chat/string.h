void memcpy(void *array, void *array0, int count);
    //@ requires chars(array, ?cs) &*& [?f]chars(array0, ?cs0) &*& count == chars_length(cs) &*& count == chars_length(cs0);
    //@ ensures chars(array, cs0) &*& [f]chars(array0, cs0);

int strlen(char *string);
    //@ requires [?f]chars(string, ?cs) &*& chars_contains(cs, 0) == true;
    //@ ensures [f]chars(string, cs) &*& result == chars_index_of(cs, 0);

int memcmp(char *array, char *array0, int count);
    //@ requires [?f]chars(array, ?cs) &*& [?f0]chars(array0, ?cs0) &*& count == chars_length(cs) &*& count == chars_length(cs0);
    //@ ensures [f]chars(array, cs) &*& [f0]chars(array0, cs0);