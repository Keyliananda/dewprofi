<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\HumidityController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['status' => 'ok']);
Route::post('/psychrometrics', [HumidityController::class, 'calculate']);
Route::get('/example-places', [HumidityController::class, 'examplePlaces']);
Route::get('/places', [HumidityController::class, 'searchPlaces']);
Route::get('/weather', [HumidityController::class, 'weather']);

Route::post('/register', [AuthController::class, 'register'])->middleware('guest');
Route::post('/login', [AuthController::class, 'login'])->middleware('guest');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
});

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
