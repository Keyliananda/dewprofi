<?php

return [
    'registration' => [
        'enabled' => env('DEWPROFI_REGISTRATION_ENABLED', false),
    ],

    'superuser' => [
        'name' => env('DEWPROFI_SUPERUSER_NAME', 'Dewprofi Admin'),
        'email' => env('DEWPROFI_SUPERUSER_EMAIL'),
        'password' => env('DEWPROFI_SUPERUSER_PASSWORD'),
    ],
];
