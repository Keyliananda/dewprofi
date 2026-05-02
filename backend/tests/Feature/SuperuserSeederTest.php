<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class SuperuserSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_superuser_is_seeded_from_configured_credentials(): void
    {
        Config::set('dewprofi.superuser.name', 'Release Admin');
        Config::set('dewprofi.superuser.email', 'admin@dewprofi.test');
        Config::set('dewprofi.superuser.password', 'secure-password-123');

        $this->seed(DatabaseSeeder::class);

        $user = User::query()
            ->where('email', 'admin@dewprofi.test')
            ->firstOrFail();

        $this->assertSame('Release Admin', $user->name);
        $this->assertTrue(Hash::check('secure-password-123', $user->password));
        $this->assertTrue($user->isSuperAdmin());
        $this->assertTrue($user->canAccessPanel());
        $this->assertNotNull($user->email_verified_at);
    }
}
