<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\HumidityController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['status' => 'ok']);
Route::post('/psychrometrics', [HumidityController::class, 'calculate'])->middleware('throttle:120,1');
Route::get('/example-places', [HumidityController::class, 'examplePlaces'])->middleware('throttle:120,1');
Route::get('/places', [HumidityController::class, 'searchPlaces'])->middleware('throttle:30,1');
Route::get('/weather', [HumidityController::class, 'weather'])->middleware('throttle:60,1');

Route::post('/register', [AuthController::class, 'register'])->middleware(['guest', 'throttle:3,1']);
Route::post('/login', [AuthController::class, 'login'])->middleware(['guest', 'throttle:5,1']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
});
