<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $email = config('dewprofi.superuser.email');
        $password = config('dewprofi.superuser.password');

        if (! is_string($email) || $email === '' || ! is_string($password) || $password === '') {
            $this->command?->warn('Superuser seeding skipped: DEWPROFI_SUPERUSER_EMAIL and DEWPROFI_SUPERUSER_PASSWORD must be set.');

            return;
        }

        User::query()->updateOrCreate([
            'email' => $email,
        ], [
            'name' => config('dewprofi.superuser.name', 'Dewprofi Admin'),
            'password' => $password,
            'email_verified_at' => now(),
            'is_super_admin' => true,
        ]);
    }
}
