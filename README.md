# SpaceAce object structure verifier for Godot

This code was written using [Godot](https://godotengine.org/) 3.3.2.stable, and has not been tested with previous versions of the engine.

&nbsp;

## What it does
This code allows you to verify that a Godo Dictionary matches an
expected structure. This is useful, for example, when you are loading data from disk and want to make sure that what you loaded is valid.

&nbsp;

## Requirements

- Godot. I wrote this with 3.3.2.stable; it may or may not work with other versions.
- [DebugHandler](https://github.com/SpaceAceMonkey/spaceace.godot.debughandler)
  - DebugHandler is used throughout this library to output messages, but it is trivial to remove if you don't wish to use it.

&nbsp;

## Features and brief how-to
- Check the existence of keys without caring what data they hold
  - `var structure = { "key": null }`
- Verify that a key holds an expected data type without caring about the data
  - `var structure = { "key": [] } # key must contain an array`
  - `var structure = { "key": {} } # key must contain an object`
  - `var structure = { "key": [{}] } # key must contain an array of objects`
- Verify that a key holds an expected data type and verify that the data has the right shape
  - `var structure = { "key": [{ "required_key": null }] } # requires an array of objects matching the specified structure`
  - `var structure = { "key": { "required_key": "value" } } # requires var_structure to have a single objecting matching the specified structure`
- Specify wildcard keys using `[*:key]`
  - `var structure = { [*:key]: null }`
    - Matches every item in
    ```
    # Values don't matter, because the structure did not specify any
    var object = {
         "key1": "value 1",
         "key2": [],
         "key3": {},
         "key4": null,
    }
    ```
    - Follows the same rules as any other key
    ```
    var structure = {
         "[*:key]": [{}], # must be an array of objects in the object being tested
    }

    # Matches these
    var object = {
        "some key": [
            { "some object key": "some object value" },
            { "some object key": null }
        ],
        "another key": [
            {},
            {}
        ]
    }
    # Remember that the key is a wildcard, so it will match "some key" and
    # also "another key", and verify that both have the expected value of
    # "an array of objects." Since no data structure was specified in the
    # "structure" variable, the data won't be looked at.

    # Does not match these
    var some_other_object = {}
    var another_object = { "some key": [] }
    var yet_another_object = { "a key": null }
    # ... or anything else that isn't an array of objects.
    ```
    ```
    var structure = {
         "[*:key]": { "inner key": null }, # must be an array of objects 
         in the object being tested
    }

    # Matches
    var object = {
        "a key": { "inner key": {} },
        "another key": { "inner key": [2, 4, 6, 8] },
    }
    # ... but not these
    var another_object = {
        "a key": {},
        "another key": []
    }
    ```
- Specify optional keys using `[opt:key:key_name]`
    ```
    var structure = { [opt:key:key_name]: null }

    # Matches
    var object = { "key_name": null }
    var another_object = { "key_name": [] }
    var a_third_object = {
        "some key": [],
        "some other key": { "object key": "object key value" }
    }
    var fourth_time = {
        "some other key": { "object key": "object key value" },
        "key_name": "value"
    }
    ```
  - The key `key_name` is optional, but if it _does_ exist, it must follow the same rules as all the other examples.
    ```
    var structure = { [opt:key:key_name]: [{ "key": [] }] }

    # Does not match
    var object = { "key_name": [] }
    var another_object = { "key_name": { "wrong key": [] } }
    ```

&nbsp;

## A partial example from a project of mine
```
var WORLD_DATA_STRUCTURE = {
    "world": {
        "levels": [{
            "board": {
                "margins": {"left": null, "right": null, "top": null, "bottom": null},
                "cell_size": { "x": null, "y": null },
                "cell_margins": { "left": null, "right": null, "top": null, "bottom": null },
                "blocks": {
                    "[*:key]": { "weight": null },
                },
                "cells": [],
                "[opt:key:cells_metadata]": [{
                    "[*:key]": {
                        "border_images": {
                            "left": null
                            , "right": null
                            , "top": null
                            , "bottom": null
                        }
                    },
                    "no_dinner": {
                        "border_images": {
                            "[*:key]": null
                        , "paths": []
                        }
                    },
                }]
            }
        }]
    }
}


var world = {
    "world": {
        "levels": [{
            "board": {
                "margins": { "left": 32, "right": 0, "top": 32, "bottom": 0 },
                "cell_size": { "x": 64, "y": 64 },
                "cell_margins": { "left": 4, "right": 4, "top": 4, "bottom": 4 },
                "blocks": {
                    "headphones_dude": { "weight": 2 },
                    "no_dinner": { "weight": 4 },
                    "right_arrow": { "weight": 2 },
                    "three_stars": { "weight": 2 }
                },
                "cells": [
                    [1, 1, 1, 1],
                    [1, 1, 1, 1],
                    [1, 1, 1, 1],
                    [1, 1, 1, 1]
                ],
                "cells_metadata": [{
                    "headphones_dude": {
                        "border_images": {
                            "left": "bar_left.png"
                            , "right": "bar_right.png"
                            , "top": "bar_top.png"
                            , "bottom": "bar_bottom.png"
                        }
                    },
                    "no_dinner": {
                        "border_images": {
                            "left": "bar_left.png"
                            , "right": "bar_right.png"
                            , "top": "bar_top.png"
                            , "bottom": "bar_bottom.png"
                            , "paths": [0, 0, 2, 0, 2, 0]
                        }
                    }
                }]
            }
        }]
    }
}

var result = {}
ObjectStructureVerifier.verify_json_structure(WORLD_DATA_STRUCTURE, world, result)
DebugHandler.d("Result %s" % result)
```

*Output*

`Result {error:0, errors:[]}`

The most interesting thing to note about the example above is the `cells_metadata` key. Let's have another look at it.

```
"[opt:key:cells_metadata]": [{
    "[*:key]": {
        "border_images": {
            "left": null
            , "right": null
            , "top": null
            , "bottom": null
        }
    },
    "no_dinner": {
        "border_images": {
            "[*:key]": null
            , "paths": []
        }
    },
}]
```
In the world structure definition, it is defined as `[opt:key:cells_metadata]`, meaning it is optional. However, since the `cells_metadata` key does exist in the `world` Dictionary, it must conform to the definitions found inside the `[opt:key:cells_metadata]` key of the structure.

`[*:key] {... structure ...}` says "we don't care which keys are inside `[opt:key:cells_metadata]`, but the data for each of those keys must match this structure." At the same level as the wildcard is a named key, `no_dinner`. Inside of `no_dinner` we have another wildcard followeed by a key called `paths`, which is an array. In short, this says, "Match however many keys you want, and don't worry about the data, but there _must_ be a key called `paths` with an array data type."

If you take it as a whole, you will see that `no_dinner` must match both the first wildcard key's structure, and also the one specifically named `no_dinner` The second wildcard stops us from having to type out the entire `border_images` structure a second time.

&nbsp;

## Further reading

There is another fairly detailed set of examples in the comments of the `verify_json_structure()` function.
